package cn.yooss.moodiary_native

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class McpKeepAliveService : Service() {
    private val scope = MainScope()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            val client = events
            if (client == null) {
                stopSelf()
            } else {
                scope.launch {
                    try {
                        client.onStopRequested()
                    } catch (error: Exception) {
                        if (error is CancellationException) throw error
                        Log.w("McpKeepAliveService", "Failed to request MCP shutdown", error)
                        stopSelf()
                    }
                }
            }
            return START_NOT_STICKY
        }
        val title = applicationInfo.loadLabel(packageManager).toString()
        val text = intent?.getStringExtra(EXTRA_TEXT).orEmpty()
        val stopLabel = intent?.getStringExtra(EXTRA_STOP_LABEL).orEmpty()
        val notification = buildNotification(title, text, stopLabel)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        scope.cancel()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun buildNotification(title: String, text: String, stopLabel: String): Notification {
        ensureChannel()
        val builder = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_mcp_keep_alive)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setBadgeIconType(Notification.BADGE_ICON_NONE)
            .addAction(Notification.Action.Builder(null, stopLabel, stopIntent()).build())
        launchIntent()?.let { builder.setContentIntent(it) }
        return builder.build()
    }

    private fun ensureChannel() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            applicationInfo.loadLabel(packageManager).toString(),
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.setShowBadge(false)
        channel.setSound(null, null)
        manager.createNotificationChannel(channel)
    }

    private fun launchIntent(): PendingIntent? {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        return PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun stopIntent(): PendingIntent = PendingIntent.getService(
        this,
        1,
        Intent(this, McpKeepAliveService::class.java).setAction(ACTION_STOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    companion object {
        internal var events: BackgroundKeepAliveEvents? = null
        const val EXTRA_TEXT = "cn.yooss.moodiary_native.keepAliveText"
        const val EXTRA_STOP_LABEL = "cn.yooss.moodiary_native.keepAliveStopLabel"

        private const val ACTION_STOP = "cn.yooss.moodiary_native.STOP_MCP"
        private const val CHANNEL_ID = "mcp_keep_alive"
        private const val NOTIFICATION_ID = 4201
    }
}
