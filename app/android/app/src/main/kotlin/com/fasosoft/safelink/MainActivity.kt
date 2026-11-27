package com.fasosoft.safelink

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activité unique de SafeLink ; l'interface est entièrement en Flutter.
 *
 * Elle reçoit aussi le texte partagé depuis une autre application
 * (`ACTION_SEND`, `text/plain`, ADR 0004). Ce canal ne fait que transmettre :
 * toutes les décisions (analyser, proposer un choix, refuser) sont prises
 * côté Dart, où elles sont testées.
 *
 * Le partage reçu est gardé jusqu'à ce que l'interface le prenne
 * (méthode `take`), ce qui couvre le démarrage à froid comme à chaud :
 * à chaud, l'interface est prévenue par `available`. Aucun fichier n'est
 * ouvert et le texte n'est jamais écrit dans les journaux.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** Dernier partage reçu, pas encore pris par l'interface. */
    private var pending: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Une activité recréée (par exemple après l'arrêt de l'application
        // par le système) a déjà traité son intention : ne pas relancer
        // l'analyse.
        if (savedInstanceState == null) pending = describe(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
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
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val share = describe(intent) ?: return
        pending = share
        channel?.invokeMethod("available", null)
    }

    /**
     * Décrit un partage reçu, ou `null` si [intent] n'en est pas un.
     *
     * Champs : `type` (type MIME annoncé), `text` (texte partagé, borné à
     * [MAX_TEXT] caractères), `truncated` (texte coupé), `files` (des
     * fichiers accompagnaient le partage : ils ne sont jamais ouverts),
     * `unreadable` (contenu illisible, par exemple mal formé par
     * l'application d'origine).
     */
    private fun describe(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return null
        // Rouverte depuis les applications récentes : Android redonne
        // l'intention d'origine, déjà analysée.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        return try {
            val clip = intent.clipData
            val hasFiles = action == Intent.ACTION_SEND_MULTIPLE ||
                intent.hasExtra(Intent.EXTRA_STREAM) ||
                (clip != null && (0 until clip.itemCount).any { clip.getItemAt(it).uri != null })
            val text = if (action == Intent.ACTION_SEND) {
                intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            } else {
                null
            }
            mapOf(
                "type" to intent.type,
                "text" to text?.take(MAX_TEXT),
                "truncated" to (text != null && text.length > MAX_TEXT),
                "files" to hasFiles,
                "unreadable" to false,
            )
        } catch (e: RuntimeException) {
            // Extras mal formés (BadParcelableException…) envoyés par
            // l'application d'origine : refusés sans planter.
            mapOf(
                "type" to null,
                "text" to null,
                "truncated" to false,
                "files" to false,
                "unreadable" to true,
            )
        }
    }

    private companion object {
        const val CHANNEL = "com.fasosoft.safelink/share"

        /**
         * Longueur maximale transmise à l'interface. Elle dépasse la taille
         * d'un message analysable (10 000 caractères) pour que les liens
         * d'un long texte restent repérables.
         */
        const val MAX_TEXT = 100_000
    }
}
