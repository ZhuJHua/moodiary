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

// 前台服务，让 MCP 服务在离开 App 后仍能对外提供接口。
//
// 安卓不允许普通后台进程长期存活，只有带常驻通知的前台服务可以，所以这里的
// 通知是功能的一部分，不是提示。类型选 specialUse：dataSync 在 Android 15 上
// 有 6 小时/24 小时的上限，mediaPlayback 之类又与本应用的用途不符。
class McpKeepAliveService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 标题与正文来自 Dart 侧 l10n，缺失时用兜底文案，避免空通知
        val title = intent?.getStringExtra(EXTRA_TITLE).orEmpty().ifEmpty { DEFAULT_TITLE }
        val text = intent?.getStringExtra(EXTRA_TEXT).orEmpty()
        val notification = buildNotification(title, text)
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
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun buildNotification(title: String, text: String): Notification {
        ensureChannel()
        val builder = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(smallIcon())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setBadgeIconType(Notification.BADGE_ICON_NONE)
        // 点通知回到 App，用户才能把服务关掉
        launchIntent()?.let { builder.setContentIntent(it) }
        return builder.build()
    }

    private fun ensureChannel() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        // 渠道名只在系统设置里可见，用应用名即可，不必再走 l10n
        val channel = NotificationChannel(
            CHANNEL_ID,
            applicationInfo.loadLabel(packageManager).toString(),
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.setShowBadge(false)
        channel.setSound(null, null)
        manager.createNotificationChannel(channel)
    }

    // 小图标取自宿主应用；应用没有图标时退回系统图标，避免 setSmallIcon(0) 抛异常
    private fun smallIcon(): Int =
        applicationInfo.icon.takeIf { it != 0 } ?: android.R.drawable.stat_sys_download_done

    private fun launchIntent(): PendingIntent? {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        return PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        const val EXTRA_TITLE = "cn.yooss.moodiary_native.keepAliveTitle"
        const val EXTRA_TEXT = "cn.yooss.moodiary_native.keepAliveText"

        private const val CHANNEL_ID = "mcp_keep_alive"
        private const val NOTIFICATION_ID = 4201
        private const val DEFAULT_TITLE = "Moodiary"
    }
}
