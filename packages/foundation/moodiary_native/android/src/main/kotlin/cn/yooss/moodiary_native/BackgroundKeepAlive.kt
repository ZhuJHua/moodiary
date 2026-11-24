package cn.yooss.moodiary_native

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

class BackgroundKeepAlive(private val context: Context) : BackgroundKeepAliveApi {
    var activity: Activity? = null

    override fun isExempt(): Boolean = try {
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        power.isIgnoringBatteryOptimizations(context.packageName)
    } catch (e: Exception) {
        Log.w(TAG, "Failed to read battery optimisation state", e)
        false
    }

    override fun requestExemption() {
        if (isExempt()) return
        try {
            startIntent(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        } catch (e: Exception) {
            Log.w(TAG, "Battery optimisation settings are unavailable", e)
            openAppSettings()
        }
    }

    override fun openAppSettings() {
        startIntent(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${context.packageName}"),
            ),
        )
    }

    override fun setKeepAlive(
        enabled: Boolean,
        notificationText: String,
        stopLabel: String,
        channelName: String,
    ) {
        val intent = Intent(context, McpKeepAliveService::class.java)
            .putExtra(McpKeepAliveService.EXTRA_TEXT, notificationText)
            .putExtra(McpKeepAliveService.EXTRA_STOP_LABEL, stopLabel)
            .putExtra(McpKeepAliveService.EXTRA_CHANNEL_NAME, channelName)
        try {
            if (enabled) {
                context.startForegroundService(intent)
            } else {
                context.stopService(intent)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to toggle the keep-alive foreground service", e)
            throw e
        }
    }

    private fun startIntent(intent: Intent) {
        val activity = activity
        if (activity != null) {
            activity.startActivity(intent)
        } else {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    private companion object {
        const val TAG = "BackgroundKeepAlive"
    }
}
