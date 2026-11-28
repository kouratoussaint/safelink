package com.fasosoft.safelink

import android.app.StatusBarManager
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activité unique de SafeLink ; l'interface est entièrement en Flutter.
 *
 * Elle reçoit aussi du texte venu d'ailleurs, par trois chemins, sans
 * aucune permission (ADR 0004 et 0014) :
 * - « Partager → Vérifier avec SafeLink » (`ACTION_SEND`, `text/plain`) ;
 * - « Vérifier avec SafeLink » dans le menu de sélection de texte
 *   (`ACTION_PROCESS_TEXT`) ;
 * - la tuile du volet des réglages rapides, qui ouvre SafeLink par l'alias
 *   non exporté `.ClipboardCheck` : le texte copié est lu une fois la
 *   fenêtre au premier plan (Android 10 et suivants ne le permettent qu'à
 *   ce moment-là). Une autre application ne peut pas demander cette
 *   lecture.
 *
 * Ce canal ne fait que transmettre : toutes les décisions (analyser,
 * proposer un choix, refuser) sont prises côté Dart, où elles sont
 * testées. Le partage reçu est gardé jusqu'à ce que l'interface le prenne
 * (méthode `take`) ; à chaud, l'interface est prévenue par `available`.
 * Aucun fichier n'est ouvert ; le texte n'est jamais écrit dans les
 * journaux.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var shortcuts: MethodChannel? = null

    /** Dernier partage reçu, pas encore pris par l'interface. */
    private var pending: Map<String, Any?>? = null

    /** La tuile a demandé de vérifier le texte copié. */
    private var clipboardRequested = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // Une activité recréée (par exemple après l'arrêt de l'application
        // par le système) a déjà traité son intention : ne pas relancer
        // l'analyse.
        if (savedInstanceState == null) receive(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        channel = MethodChannel(messenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "take" -> {
                        result.success(pending)
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        shortcuts = MethodChannel(messenger, SHORTCUTS_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "canRequestTile" ->
                        result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                    "requestTile" -> requestTile(result)
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        shortcuts?.setMethodCallHandler(null)
        shortcuts = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
        if (clipboardRequested && hasWindowFocus()) {
            window.decorView.post { readClipboard() }
        } else if (pending != null) {
            channel?.invokeMethod("available", null)
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && clipboardRequested) readClipboard()
    }

    /** Range ce qu'apporte [intent] : un partage, ou la lecture à faire. */
    private fun receive(intent: Intent?) {
        if (intent == null) return
        // Rouverte depuis les applications récentes : Android redonne
        // l'intention d'origine, déjà traitée.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        if (intent.component?.className == CLIPBOARD_ALIAS) {
            clipboardRequested = true
            return
        }
        describe(intent)?.let { pending = it }
    }

    /**
     * Décrit un partage ou une sélection reçus, ou `null` si [intent] n'en
     * est pas un.
     *
     * Champs : `source` (`share` ou `selection`), `type` (type MIME
     * annoncé), `text` (texte, borné à [MAX_TEXT] caractères), `truncated`
     * (texte coupé), `files` (des fichiers accompagnaient le partage : ils
     * ne sont jamais ouverts), `unreadable` (contenu illisible, par exemple
     * mal formé par l'application d'origine).
     */
    private fun describe(intent: Intent): Map<String, Any?>? {
        val action = intent.action
        val selection = action == Intent.ACTION_PROCESS_TEXT
        if (!selection && action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            return null
        }
        val source = if (selection) "selection" else "share"
        return try {
            val clip = intent.clipData
            val hasFiles = !selection && (
                action == Intent.ACTION_SEND_MULTIPLE ||
                    intent.hasExtra(Intent.EXTRA_STREAM) ||
                    (clip != null && (0 until clip.itemCount).any { clip.getItemAt(it).uri != null })
                )
            val text = when (action) {
                Intent.ACTION_PROCESS_TEXT ->
                    intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
                Intent.ACTION_SEND ->
                    intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
                else -> null
            }
            textMap(source, intent.type, text, files = hasFiles)
        } catch (e: RuntimeException) {
            // Extras mal formés (BadParcelableException…) envoyés par
            // l'application d'origine : refusés sans planter.
            unreadable(source)
        }
    }

    /**
     * Lit le texte copié, une seule fois, puis le transmet comme un partage
     * (`source` = `clipboard`). Un contenu marqué secret par Android 13 et
     * suivants (mot de passe, code) n'est pas lu.
     */
    private fun readClipboard() {
        if (!clipboardRequested) return
        clipboardRequested = false
        pending = try {
            val manager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = manager.primaryClip
            val description = manager.primaryClipDescription
            val sensitive = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                description?.extras?.getBoolean(ClipDescription.EXTRA_IS_SENSITIVE) == true
            if (sensitive) {
                textMap("clipboard", null, null, sensitive = true)
            } else {
                val text = if (clip != null && clip.itemCount > 0) {
                    clip.getItemAt(0).coerceToText(this)?.toString()
                } else {
                    null
                }
                textMap("clipboard", description?.getMimeType(0), text)
            }
        } catch (e: RuntimeException) {
            unreadable("clipboard")
        }
        channel?.invokeMethod("available", null)
    }

    private fun textMap(
        source: String,
        type: String?,
        text: String?,
        files: Boolean = false,
        sensitive: Boolean = false,
    ): Map<String, Any?> = mapOf(
        "source" to source,
        "type" to type,
        "text" to text?.take(MAX_TEXT),
        "truncated" to (text != null && text.length > MAX_TEXT),
        "files" to files,
        "unreadable" to false,
        "sensitive" to sensitive,
    )

    private fun unreadable(source: String): Map<String, Any?> = mapOf(
        "source" to source,
        "type" to null,
        "text" to null,
        "truncated" to false,
        "files" to false,
        "unreadable" to true,
        "sensitive" to false,
    )

    /**
     * Propose d'ajouter la tuile au volet (Android 13 et suivants) ; répond
     * `added`, `already`, `refused` ou `unsupported`.
     */
    private fun requestTile(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success("unsupported")
            return
        }
        val manager = getSystemService(StatusBarManager::class.java)
        if (manager == null) {
            result.success("unsupported")
            return
        }
        var answered = false
        manager.requestAddTileService(
            ComponentName(this, ClipboardTileService::class.java),
            getString(R.string.tile_label),
            Icon.createWithResource(this, R.drawable.ic_tile),
            mainExecutor,
        ) { code ->
            if (answered) return@requestAddTileService
            answered = true
            result.success(
                when (code) {
                    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
                    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "already"
                    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED -> "refused"
                    else -> "unsupported"
                },
            )
        }
    }

    companion object {
        private const val CHANNEL = "com.fasosoft.safelink/share"
        private const val SHORTCUTS_CHANNEL = "com.fasosoft.safelink/shortcuts"

        /** Alias non exporté qui demande la lecture du texte copié. */
        const val CLIPBOARD_ALIAS = "com.fasosoft.safelink.ClipboardCheck"

        /**
         * Longueur maximale transmise à l'interface. Elle dépasse la taille
         * d'un message analysable (10 000 caractères) pour que les liens
         * d'un long texte restent repérables.
         */
        private const val MAX_TEXT = 100_000
    }
}
