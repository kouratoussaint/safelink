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
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Bulle flottante de SafeLink (ADR 0014), en option, désactivée par défaut.
 *
 * Une petite pastille reste au bord de l'écran, par-dessus les autres
 * applications. La toucher ouvre SafeLink sur la vérification du texte
 * copié (même entrée que la tuile du volet). On la déplace en la faisant
 * glisser ; la lâcher sur la croix en bas de l'écran la ferme et la
 * désactive.
 *
 * Elle ne lit rien elle-même : ni l'écran, ni le texte copié. Elle demande
 * l'autorisation « Afficher par-dessus d'autres applis », indisponible sur
 * Android Go (Android 10 et suivants) ; elle n'est donc proposée que si le
 * téléphone la permet. Un service au premier plan la garde en vie, avec une
 * notification discrète qui permet de l'arrêter.
 */
@TargetApi(Build.VERSION_CODES.O)
class BubbleService : Service() {
    private lateinit var windowManager: WindowManager
    private var bubble: View? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var closeTarget: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
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
        if (bubble == null) showBubble()
        instance = this
        applyHidden()
        return START_STICKY
    }

    override fun onDestroy() {
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
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
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
            contentDescription = getString(R.string.bubble_description)
        }
        // Un peu de marge autour du disque pour que l'ombre ne soit pas
        // coupée.
        val view = FrameLayout(this).apply {
            addView(icon, FrameLayout.LayoutParams(size, size, Gravity.CENTER))
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
        var dragging = false
        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
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
                        val close = overClose(event.rawX, event.rawY)
                        hideCloseTarget()
                        if (close) {
                            setEnabled(this, false)
                            stopSelf()
                        } else {
                            snapToEdge(view, params)
                        }
                    } else if (event.actionMasked == MotionEvent.ACTION_UP) {
                        view.performClick()
                        openCheck()
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

    /** Ouvre SafeLink sur la vérification du texte copié. */
    private fun openCheck() {
        startActivity(
            Intent()
                .setComponent(ComponentName(this, MainActivity.CLIPBOARD_ALIAS))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    private fun snapToEdge(view: View, params: WindowManager.LayoutParams) {
        val width = resources.displayMetrics.widthPixels
        val target = if (params.x + view.width / 2 < width / 2) 0 else width - view.width
        val maxY = resources.displayMetrics.heightPixels - view.height
        params.y = params.y.coerceIn(0, maxY.coerceAtLeast(0))
        ValueAnimator.ofInt(params.x, target).apply {
            duration = if (animationsOff()) 0 else 220
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

    /** Cache la bulle pendant que SafeLink est à l'écran. */
    private fun applyHidden() {
        bubble?.visibility = if (hiddenBySafeLink) View.GONE else View.VISIBLE
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

        private var instance: BubbleService? = null
        private var hiddenBySafeLink = false

        /**
         * Le téléphone permet la bulle : Android 8 ou plus, et pas un
         * Android Go (Android 10 et suivants y refusent l'autorisation).
         */
        fun supported(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
            val activity = context.getSystemService(ActivityManager::class.java)
            return !(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && activity.isLowRamDevice)
        }

        fun canDraw(context: Context): Boolean =
            supported(context) && Settings.canDrawOverlays(context)

        /** État lu par l'interface : permise, autorisée, choisie. */
        fun state(context: Context): Map<String, Any> = mapOf(
            "supported" to supported(context),
            "permitted" to canDraw(context),
            "enabled" to (isEnabled(context) && canDraw(context)),
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

        /** SafeLink passe au premier plan (cacher) ou le quitte (montrer). */
        fun setHiddenBySafeLink(hidden: Boolean) {
            hiddenBySafeLink = hidden
            instance?.applyHidden()
        }
    }
}
