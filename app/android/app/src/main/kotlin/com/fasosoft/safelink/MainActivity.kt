package com.fasosoft.safelink

import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activité principale de SafeLink ; l'interface est entièrement en Flutter.
 *
 * Elle reçoit aussi du texte venu d'ailleurs, sans aucune permission
 * (ADR 0004, 0014 et 0015) :
 * - « Partager → Vérifier avec SafeLink » (`ACTION_SEND`, `text/plain`) ;
 * - « Vérifier avec SafeLink » dans le menu de sélection de texte
 *   (`ACTION_PROCESS_TEXT`) ;
 * - « Tout voir dans SafeLink » depuis le panneau rapide
 *   ([QuickCheckActivity]), par l'alias non exporté `.OpenCheck` : la
 *   vérification choisie dans le panneau est refaite ici en entier. Une
 *   autre application ne peut pas emprunter ce chemin.
 *
 * La tuile du volet et la bulle flottante ouvrent le panneau rapide, pas
 * cette activité.
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

    override fun onCreate(savedInstanceState: Bundle?) {
        // Une activité recréée (par exemple après l'arrêt de l'application
        // par le système) a déjà traité son intention : ne pas relancer
        // l'analyse.
        if (savedInstanceState == null) receive(intent)
        super.onCreate(savedInstanceState)
        // Bulle choisie et toujours permise : la relancer (par exemple après
        // un redémarrage du téléphone).
        BubbleService.startIfEnabled(this)
    }

    override fun onResume() {
        super.onResume()
        BubbleService.screenShown()
    }

    override fun onPause() {
        BubbleService.screenHidden()
        super.onPause()
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
                    "bubbleState" -> result.success(BubbleService.state(this@MainActivity))
                    "openOverlaySettings" -> {
                        result.success(openOverlaySettings())
                    }
                    "setBubble" -> {
                        val enabled = call.argument<Boolean>("enabled") == true
                        if (enabled && BubbleService.canDraw(this@MainActivity)) {
                            BubbleService.setEnabled(this@MainActivity, true)
                            BubbleService.startIfEnabled(this@MainActivity)
                        } else if (!enabled) {
                            BubbleService.setEnabled(this@MainActivity, false)
                            BubbleService.stop(this@MainActivity)
                        }
                        result.success(BubbleService.state(this@MainActivity))
                    }
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
        if (pending != null) channel?.invokeMethod("available", null)
    }

    /** Range ce qu'apporte [intent] : un partage, ou une vérification. */
    private fun receive(intent: Intent?) {
        if (intent == null) return
        // Rouverte depuis les applications récentes : Android redonne
        // l'intention d'origine, déjà traitée.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val handOver = if (intent.component?.className == OPEN_CHECK_ALIAS) {
            handedOver(intent)
        } else {
            describe(intent)
        }
        handOver?.let { pending = it }
    }

    /**
     * Vérification transmise par le panneau rapide : `source` = `quick`,
     * `kind` (`link` ou `message`), `text`, et `historyId`, l'identifiant
     * sous lequel le panneau l'a peut-être enregistrée (la nouvelle analyse
     * la remplace, sans doublon).
     */
    private fun handedOver(intent: Intent): Map<String, Any?>? = try {
        val kind = intent.getStringExtra(QuickCheckActivity.EXTRA_KIND)
        val text = intent.getStringExtra(QuickCheckActivity.EXTRA_TEXT)
        if ((kind != "link" && kind != "message") || text.isNullOrEmpty()) {
            null
        } else {
            mapOf(
                "source" to "quick",
                "kind" to kind,
                "text" to text.take(SharedPayload.MAX_TEXT),
                "historyId" to intent.getStringExtra(QuickCheckActivity.EXTRA_HISTORY_ID),
            )
        }
    } catch (e: RuntimeException) {
        null
    }

    /**
     * Décrit un partage ou une sélection reçus, ou `null` si [intent] n'en
     * est pas un.
     *
     * Champs : voir [SharedPayload] ; `source` vaut `share` ou
     * `selection`.
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
            SharedPayload.text(source, intent.type, text, files = hasFiles)
        } catch (e: RuntimeException) {
            // Extras mal formés (BadParcelableException…) envoyés par
            // l'application d'origine : refusés sans planter.
            SharedPayload.unreadable(source)
        }
    }

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

    /** Ouvre le réglage « Afficher par-dessus d'autres applis » de SafeLink. */
    private fun openOverlaySettings(): Boolean {
        if (!BubbleService.supported(this)) return false
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName"),
                ),
            )
            true
        } catch (e: RuntimeException) {
            false
        }
    }

    companion object {
        private const val CHANNEL = "com.fasosoft.safelink/share"
        private const val SHORTCUTS_CHANNEL = "com.fasosoft.safelink/shortcuts"

        /**
         * Alias non exporté par lequel le panneau rapide ouvre une
         * vérification en entier.
         */
        const val OPEN_CHECK_ALIAS = "com.fasosoft.safelink.OpenCheck"
    }
}
