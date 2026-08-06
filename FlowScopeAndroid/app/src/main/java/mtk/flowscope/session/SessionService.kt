package mtk.flowscope.session

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import mtk.flowscope.MainActivity
import mtk.flowscope.R
import mtk.flowscope.data.LiveSessionState
import mtk.flowscope.data.PendingMoodQueue
import mtk.flowscope.data.SharedThemeStore
import mtk.flowscope.util.colorFromHex
import androidx.compose.ui.graphics.toArgb

/**
 * Android's answer to the iOS Live Activity.
 *
 * iOS put a running session on the Lock Screen and Dynamic Island via
 * ActivityKit. Android has no equivalent surface, so the same two jobs — keeping
 * the session alive while the app is backgrounded, and showing it at a glance
 * with one-tap mood logging — are handled by a foreground service with an
 * ongoing notification.
 *
 * The notification uses a chronometer anchored to the wall-clock start, so it
 * keeps ticking accurately without the app pushing an update every second.
 */
class SessionService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_LOG_MOOD -> {
                val level = intent.getIntExtra(EXTRA_LEVEL, 50)
                PendingMoodQueue.enqueue(this, level)
            }

            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
        }

        // startForeground must always be called once we've been started with
        // startForegroundService, even on the bail-out path — skipping it
        // crashes the process with ForegroundServiceDidNotStartInTime.
        createChannel()
        val notification = buildNotification()
        // FOREGROUND_SERVICE_TYPE_SPECIAL_USE only exists from API 34; earlier
        // releases take the untyped overload.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        if (LiveSessionState.read(this) == null) {
            // No session to track — tear down rather than leave a stale timer.
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    private fun createChannel() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Focus session",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps your running FlowScope session visible and alive."
                setShowBadge(false)
                enableVibration(false)
            },
        )
    }

    private fun buildNotification(): Notification {
        val snapshot = LiveSessionState.read(this)
        val palette = SharedThemeStore.read(this)
        val accent = colorFromHex(palette.primaryHex).toArgb()

        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val title = snapshot?.name?.takeIf { it.isNotBlank() } ?: "Focus session"
        val moodCount = snapshot?.moodCount ?: 0
        val category = snapshot?.category ?: "General"
        val paused = snapshot?.isPaused == true

        val subtitle = buildString {
            append(category)
            append(" · ")
            append(moodCount)
            append(if (moodCount == 1) " log" else " logs")
            if (paused) append(" · Paused")
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_flowscope)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setSilent(true)
            .setColor(accent)
            .setColorized(true)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        if (snapshot != null && !paused) {
            // Anchoring to the wall-clock base lets the system tick the timer
            // for us — no per-second updates from the app.
            builder.setUsesChronometer(true)
            builder.setWhen(snapshot.timerBase)
            builder.setShowWhen(true)
        } else if (snapshot != null) {
            builder.setUsesChronometer(false)
            builder.setSubText(formatDuration(snapshot.elapsed))
        }

        // The same three quick-log levels the iOS widget offered.
        builder.addAction(moodAction("🙁 Low", 20))
        builder.addAction(moodAction("😐 Okay", 60))
        builder.addAction(moodAction("🙂 Great", 95))

        return builder.build()
    }

    private fun moodAction(label: String, level: Int): NotificationCompat.Action {
        val intent = Intent(this, SessionService::class.java)
            .setAction(ACTION_LOG_MOOD)
            .putExtra(EXTRA_LEVEL, level)
        val pending = PendingIntent.getService(
            this,
            level,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Action.Builder(0, label, pending).build()
    }

    companion object {
        private const val CHANNEL_ID = "flowscope.session"
        private const val NOTIFICATION_ID = 1001

        const val ACTION_LOG_MOOD = "mtk.flowscope.LOG_MOOD"
        const val ACTION_STOP = "mtk.flowscope.STOP"
        const val EXTRA_LEVEL = "level"

        fun notificationsAllowed(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
            return ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        }

        fun start(context: Context) {
            val intent = Intent(context, SessionService::class.java)
            ContextCompat.startForegroundService(context, intent)
        }

        /** Rebuilds the notification in place (mood count, pause state, theme). */
        fun update(context: Context) = start(context)

        fun stop(context: Context) {
            context.stopService(Intent(context, SessionService::class.java))
        }
    }
}
