package com.fasosoft.safelink

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Panneau rapide de SafeLink (ADR 0015) : une carte posée par-dessus
 * l'application en cours, qui vérifie le texte copié et montre l'essentiel
 * du résultat, sans ouvrir tout SafeLink.
 *
 * Ouvert par la bulle flottante, la tuile du volet et la notification de
 * la bulle ; non exporté, aucune autre application ne peut l'ouvrir. Il a
 * sa propre tâche, absente des applications récentes, et se ferme dès
 * qu'on le quitte : Retour, ou toucher à côté, ramène à l'application
 * d'où l'on venait.
 *
 * Le texte copié est lu une seule fois par ouverture, quand la fenêtre a
 * le focus (seul moment où Android 10 et suivants le permettent). Un texte
 * marqué secret n'est pas lu. L'interface est en Flutter, avec son propre
 * point d'entrée (`quickCheckMain`) et le même moteur d'analyse que
 * l'application.
 */
class QuickCheckActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** Lecture du presse-papiers, pas encore prise par l'interface. */
    private var pending: Map<String, Any?>? = null

    /** Le texte copié reste à lire, dès que la fenêtre aura le focus. */
    private var readRequested = false

    override fun onCreate(savedInstanceState: Bundle?) {
        readRequested = true
        super.onCreate(savedInstanceState)
        // Assombrit l'application du dessous dès l'ouverture, avant même le
        // premier rendu de Flutter.
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.setDimAmount(DIM)
    }

    override fun getDartEntrypointFunctionName(): String = "quickCheckMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "take" -> {
                        result.success(pending)
                        pending = null
                    }
                    "close" -> {
                        result.success(null)
                        close()
                    }
                    "openInApp" -> {
                        result.success(
                            openInApp(
                                call.argument<String>("kind"),
                                call.argument<String>("text"),
                                call.argument<String>("historyId"),
                            ),
                        )
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

    override fun onResume() {
        super.onResume()
        BubbleService.screenShown()
    }

    override fun onPause() {
        BubbleService.screenHidden()
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Panneau déjà ouvert, bulle ou tuile touchée de nouveau : relire.
        readRequested = true
        if (hasWindowFocus()) window.decorView.post { readClipboard() }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && readRequested) readClipboard()
    }

    private fun readClipboard() {
        if (!readRequested) return
        readRequested = false
        pending = SharedPayload.clipboard(this)
        channel?.invokeMethod("available", null)
    }

    /**
     * Ouvre la vérification en entier dans SafeLink, puis ferme le
     * panneau. Répond `false` si la demande est incomplète.
     */
    private fun openInApp(kind: String?, text: String?, historyId: String?): Boolean {
        if ((kind != "link" && kind != "message") || text.isNullOrEmpty()) return false
        return try {
            startActivity(
                Intent()
                    .setComponent(ComponentName(this, MainActivity.OPEN_CHECK_ALIAS))
                    .putExtra(EXTRA_KIND, kind)
                    .putExtra(EXTRA_TEXT, text.take(SharedPayload.MAX_TEXT))
                    .putExtra(EXTRA_HISTORY_ID, historyId)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            close()
            true
        } catch (e: RuntimeException) {
            false
        }
    }

    /** Ferme le panneau sans animation d'Android : Flutter a déjà animé. */
    private fun close() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            overrideActivityTransition(Activity.OVERRIDE_TRANSITION_CLOSE, 0, 0)
            finish()
        } else {
            finish()
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
    }

    companion object {
        private const val CHANNEL = "com.fasosoft.safelink/quick"
        private const val DIM = 0.45f

        const val EXTRA_KIND = "com.fasosoft.safelink.extra.KIND"
        const val EXTRA_TEXT = "com.fasosoft.safelink.extra.TEXT"
        const val EXTRA_HISTORY_ID = "com.fasosoft.safelink.extra.HISTORY_ID"

        /** Intention qui ouvre le panneau, depuis un service ou la tuile. */
        fun intent(context: Context): Intent =
            Intent(context, QuickCheckActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
}
