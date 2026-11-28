package com.fasosoft.safelink

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.annotation.TargetApi
import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import io.flutter.FlutterInjector
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Bulle flottante de SafeLink (ADR 0014 et 0015), en option, désactivée
 * par défaut.
 *
 * La toucher ouvre le panneau rapide ([QuickCheckActivity]), qui vérifie
 * le texte copié par-dessus l'application en cours. On la déplace en la
 * faisant glisser ; la lâcher sur la croix en bas de l'écran la ferme et
 * la désactive.
 *
 * Elle ne reste pas affichée : après quelques secondes sans être touchée,
 * - jusqu'à Android 9, elle disparaît, et revient quand un texte est
 *   copié : Android prévient SafeLink de la copie, sans lui montrer le
 *   texte (seul son type est regardé, pour ignorer une image) ;
 * - à partir d'Android 10, qui ne prévient plus aucune application d'une
 *   copie, elle se range à moitié dans le bord de l'écran, pâlie ; la
 *   toucher ouvre le panneau.
 * Elle se cache tant que SafeLink (application ou panneau) est à l'écran.
 *
 * Elle ne lit rien elle-même : ni l'écran, ni le texte copié. Elle demande
 * l'autorisation « Afficher par-dessus d'autres applis », indisponible sur
 * Android Go (Android 10 et suivants) ; elle n'est donc proposée que si le
 * téléphone la permet. Un service au premier plan la garde en vie, avec une
 * notification discrète qui ouvre le panneau et permet de l'arrêter.
 */
@TargetApi(Build.VERSION_CODES.O)
class BubbleService : Service() {
    private lateinit var windowManager: WindowManager
    private var bubble: View? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var closeTarget: View? = null

    private val handler = Handler(Looper.getMainLooper())
    private val restLater = Runnable { rest() }
    private var positionAnimator: ValueAnimator? = null

    /** Bulle montrée en entier ; sinon au repos (cachée ou rangée). */
    private var awake = false

    /** Bulle en train d'être glissée. */
    private var dragging = false

    /** Montrer la bulle en entier au premier départ de SafeLink. */
    private var introPending = false

    private var clipboard: ClipboardManager? = null
    private val copyListener = ClipboardManager.OnPrimaryClipChangedListener {
        handler.post { onCopy() }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        // Prépare Flutter pendant que la bulle attend : le panneau s'ouvre
        // plus vite.
        try {
            FlutterInjector.instance().flutterLoader().startInitialization(applicationContext)
        } catch (e: RuntimeException) {
            // Le panneau s'initialisera lui-même.
        }
        if (detectsCopies()) {
            clipboard = getSystemService(ClipboardManager::class.java)
            clipboard?.addPrimaryClipChangedListener(copyListener)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            setEnabled(this, false)
            stopSelf()
            return START_NOT_STICKY
        }
        if (!isEnabled(this) || !canDraw(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground()
        if (bubble == null) {
            showBubble()
            introPending = true
        }
        instance = this
        render()
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        positionAnimator?.cancel()
        clipboard?.removePrimaryClipChangedListener(copyListener)
        removeView(bubble)
        removeView(closeTarget)
        bubble = null
        closeTarget = null
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                NOTIFICATION_CHANNEL,
                getString(R.string.bubble_channel),
                NotificationManager.IMPORTANCE_MIN,
            ).apply { setShowBadge(false) },
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, BubbleService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val open = PendingIntent.getActivity(
            this,
            2,
            QuickCheckActivity.intent(this),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = Notification.Builder(this, NOTIFICATION_CHANNEL)
            .setSmallIcon(R.drawable.ic_tile)
            .setContentTitle(getString(R.string.bubble_notification_title))
            .setContentText(getString(R.string.bubble_notification_text))
            .setContentIntent(open)
            .setOngoing(true)
            .addAction(
                Notification.Action.Builder(
                    null,
                    getString(R.string.bubble_notification_stop),
                    stop,
                ).build(),
            )
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun overlayParams(width: Int, height: Int) = WindowManager.LayoutParams(
        width,
        height,
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT,
    ).apply { gravity = Gravity.TOP or Gravity.START }

    @SuppressLint("ClickableViewAccessibility")
    private fun showBubble() {
        val size = dp(56)
        val icon = ImageView(this).apply {
            setImageResource(R.drawable.ic_tile)
            val padding = dp(14)
            setPadding(padding, padding, padding, padding)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(BRAND_TEAL)
            }
            elevation = dp(6).toFloat()
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        // Un peu de marge autour du disque pour que l'ombre ne soit pas
        // coupée. Le cadre porte la description et l'action, pour TalkBack.
        val view = FrameLayout(this).apply {
            addView(icon, FrameLayout.LayoutParams(size, size, Gravity.CENTER))
            contentDescription = getString(R.string.bubble_description)
            setOnClickListener { openCheck() }
        }
        val frame = size + dp(12)
        val metrics = resources.displayMetrics
        val params = overlayParams(frame, frame).apply {
            x = metrics.widthPixels - frame
            y = metrics.heightPixels / 3
        }
        val slop = ViewConfiguration.get(this).scaledTouchSlop
        var startX = 0
        var startY = 0
        var touchX = 0f
        var touchY = 0f
        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    // Touchée : elle ne se range pas pendant qu'on la tient.
                    handler.removeCallbacks(restLater)
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    dragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchX
                    val dy = event.rawY - touchY
                    if (!dragging && hypot(dx, dy) > slop) {
                        dragging = true
                        positionAnimator?.cancel()
                        view.animate().cancel()
                        view.alpha = 1f
                        showCloseTarget()
                    }
                    if (dragging) {
                        params.x = startX + dx.toInt()
                        params.y = startY + dy.toInt()
                        windowManager.updateViewLayout(view, params)
                        highlightCloseTarget(overClose(event.rawX, event.rawY))
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (dragging) {
                        dragging = false
                        val close = overClose(event.rawX, event.rawY)
                        hideCloseTarget()
                        if (close) {
                            setEnabled(this, false)
                            stopSelf()
                        } else {
                            val maxY = resources.displayMetrics.heightPixels - view.height
                            params.y = params.y.coerceIn(0, maxY.coerceAtLeast(0))
                            windowManager.updateViewLayout(view, params)
                            wake()
                        }
                    } else if (event.actionMasked == MotionEvent.ACTION_UP) {
                        view.performClick()
                    } else if (awake) {
                        handler.postDelayed(restLater, AWAKE_MS)
                    }
                    true
                }
                else -> false
            }
        }
        windowManager.addView(view, params)
        bubble = view
        bubbleParams = params
    }

    /** Ouvre le panneau rapide sur la vérification du texte copié. */
    private fun openCheck() {
        // Après le panneau, la bulle retourne au repos.
        awake = false
        handler.removeCallbacks(restLater)
        try {
            startActivity(QuickCheckActivity.intent(this))
        } catch (e: RuntimeException) {
            render()
        }
    }

    /** Montre la bulle en entier, puis la remet au repos après un temps. */
    private fun wake() {
        val view = bubble ?: return
        val hidden = view.visibility != View.VISIBLE
        awake = true
        handler.removeCallbacks(restLater)
        handler.postDelayed(restLater, AWAKE_MS)
        render()
        if (hidden && view.visibility == View.VISIBLE && !animationsOff()) {
            view.scaleX = 0.6f
            view.scaleY = 0.6f
            view.alpha = 0f
            view.animate().scaleX(1f).scaleY(1f).alpha(1f)
                .setDuration(220).setInterpolator(DecelerateInterpolator()).start()
        }
    }

    private fun rest() {
        awake = false
        render()
    }

    /** Un texte vient d'être copié (Android 9 et avant) : se montrer. */
    private fun onCopy() {
        if (bubble == null || screens > 0) return
        // Seul le type du contenu copié est regardé, jamais le texte.
        val text = try {
            clipboard?.primaryClipDescription?.hasMimeType("text/*") == true
        } catch (e: RuntimeException) {
            false
        }
        if (text) wake()
    }

    /**
     * Affiche la bulle selon l'état : cachée si SafeLink est à l'écran,
     * entière si elle est réveillée, sinon au repos (cachée jusqu'à
     * Android 9, rangée au bord ensuite).
     */
    private fun render() {
        val view = bubble ?: return
        if (screens > 0) {
            view.visibility = View.GONE
            return
        }
        if (introPending) {
            introPending = false
            wake()
            return
        }
        when {
            awake || dragging -> {
                view.visibility = View.VISIBLE
                tuck(false)
            }
            detectsCopies() -> view.visibility = View.GONE
            else -> {
                view.visibility = View.VISIBLE
                tuck(true)
            }
        }
    }

    /**
     * Range la bulle à moitié dans le bord le plus proche, pâlie
     * ([inside]), ou la ramène entière contre ce bord.
     */
    private fun tuck(inside: Boolean) {
        val view = bubble ?: return
        val params = bubbleParams ?: return
        val width = resources.displayMetrics.widthPixels
        val frame = params.width
        val left = params.x + frame / 2 < width / 2
        val target = when {
            inside && left -> -frame / 2
            inside -> width - frame / 2
            left -> 0
            else -> width - frame
        }
        val duration = if (animationsOff()) 0L else 220L
        view.animate().alpha(if (inside) TUCKED_ALPHA else 1f).setDuration(duration).start()
        if (params.x == target) return
        positionAnimator?.cancel()
        positionAnimator = ValueAnimator.ofInt(params.x, target).apply {
            this.duration = duration
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                if (view.isAttachedToWindow) {
                    params.x = it.animatedValue as Int
                    windowManager.updateViewLayout(view, params)
                }
            }
            start()
        }
    }

    private fun showCloseTarget() {
        if (closeTarget != null) return
        val size = dp(64)
        val view = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            val padding = dp(18)
            setPadding(padding, padding, padding, padding)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(CLOSE_GREY)
            }
            contentDescription = getString(R.string.bubble_close)
        }
        val metrics = resources.displayMetrics
        val params = overlayParams(size, size).apply {
            flags = flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
            x = (metrics.widthPixels - size) / 2
            y = metrics.heightPixels - size - dp(48)
        }
        windowManager.addView(view, params)
        closeTarget = view
    }

    private fun highlightCloseTarget(active: Boolean) {
        val view = closeTarget ?: return
        (view.background as? GradientDrawable)?.setColor(if (active) CLOSE_RED else CLOSE_GREY)
        val scale = if (active) 1.2f else 1f
        view.scaleX = scale
        view.scaleY = scale
    }

    private fun hideCloseTarget() {
        removeView(closeTarget)
        closeTarget = null
    }

    private fun overClose(x: Float, y: Float): Boolean {
        val metrics = resources.displayMetrics
        val centerX = metrics.widthPixels / 2f
        val centerY = metrics.heightPixels - dp(48) - dp(32).toFloat()
        return abs(x - centerX) < dp(64) && abs(y - centerY) < dp(64)
    }

    private fun removeView(view: View?) {
        if (view?.isAttachedToWindow == true) windowManager.removeView(view)
    }

    private fun animationsOff(): Boolean =
        Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    companion object {
        private const val ACTION_STOP = "com.fasosoft.safelink.action.STOP_BUBBLE"
        private const val NOTIFICATION_CHANNEL = "bubble"
        private const val NOTIFICATION_ID = 41
        private const val PREFS = "safelink_bubble"
        private const val KEY_ENABLED = "enabled"
        private const val BRAND_TEAL = 0xFF00796B.toInt()
        private const val CLOSE_GREY = 0xCC33475B.toInt()
        private const val CLOSE_RED = 0xFFB91C1C.toInt()

        /** Temps pendant lequel la bulle reste entière sans être touchée. */
        private const val AWAKE_MS = 8_000L

        /** Opacité de la bulle rangée au bord. */
        private const val TUCKED_ALPHA = 0.55f

        private var instance: BubbleService? = null

        /** Écrans de SafeLink à l'écran (application, panneau rapide). */
        private var screens = 0

        /**
         * Le téléphone permet la bulle : Android 8 ou plus, et pas un
         * Android Go (Android 10 et suivants y refusent l'autorisation).
         */
        fun supported(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
            val activity = context.getSystemService(ActivityManager::class.java)
            return !(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && activity.isLowRamDevice)
        }

        /**
         * Android prévient d'une copie (Android 9 et avant) : la bulle peut
         * se cacher et revenir à la copie. Ensuite, elle se range au bord.
         */
        fun detectsCopies(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

        fun canDraw(context: Context): Boolean =
            supported(context) && Settings.canDrawOverlays(context)

        /** État lu par l'interface : permise, autorisée, choisie. */
        fun state(context: Context): Map<String, Any> = mapOf(
            "supported" to supported(context),
            "permitted" to canDraw(context),
            "enabled" to (isEnabled(context) && canDraw(context)),
            "detectsCopies" to detectsCopies(),
        )

        fun isEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)

        fun setEnabled(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ENABLED, enabled)
                .apply()
        }

        fun isRunning(): Boolean = instance != null

        /** Lance la bulle si elle est choisie et permise. */
        fun startIfEnabled(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            if (!isEnabled(context) || !canDraw(context)) return
            context.startForegroundService(Intent(context, BubbleService::class.java))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, BubbleService::class.java))
        }

        /** Un écran de SafeLink passe au premier plan : cacher la bulle. */
        fun screenShown() {
            screens++
            instance?.render()
        }

        /** Un écran de SafeLink quitte le premier plan. */
        fun screenHidden() {
            screens = (screens - 1).coerceAtLeast(0)
            instance?.render()
        }
    }
}
