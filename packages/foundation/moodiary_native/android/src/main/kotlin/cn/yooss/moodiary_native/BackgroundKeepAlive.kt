package cn.yooss.moodiary_native

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

// 安卓侧只负责电池优化白名单与通知权限，真正的常驻/保活不由这里实现
class BackgroundKeepAlive(private val context: Context) : BackgroundKeepAliveApi {
    var activity: Activity? = null

    override fun isExempt(): Boolean = try {
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        power.isIgnoringBatteryOptimizations(context.packageName)
    } catch (e: Exception) {
        Log.w(TAG, "Failed to read battery optimisation state", e)
        false
    }

    override fun requestExemption(): Boolean {
        if (isExempt()) return true
        val activity = activity ?: return isExempt()
        try {
            activity.startActivity(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:${context.packageName}"),
                ),
            )
        } catch (e: Exception) {
            Log.w(TAG, "Direct exemption request failed, opening settings", e)
            try {
                activity.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (fallback: Exception) {
                Log.w(TAG, "Battery optimisation settings are unavailable", fallback)
            }
        }
        // 用户要在系统弹窗里授权，这里返回调用时的状态
        return isExempt()
    }

    override fun isNotificationsEnabled(): Boolean = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // 33 起通知是运行时权限，只有用户点过允许才算打开
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            // 33 以下没有运行时权限，只能看用户在系统设置里的全局开关
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.areNotificationsEnabled()
        }
    } catch (e: Exception) {
        Log.w(TAG, "Failed to read notification permission state", e)
        false
    }

    override fun requestNotifications(): Boolean {
        if (isNotificationsEnabled()) return true
        val activity = activity
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && activity != null) {
                // 系统弹窗只会弹一次，拒绝之后只能引导用户去设置页
                activity.requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_NOTIFICATIONS,
                )
            } else {
                // 没有 Activity 或系统版本过低时，只能打开通知设置让用户自己开
                openNotificationSettings()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Requesting notification permission failed, opening settings", e)
            try {
                openNotificationSettings()
            } catch (fallback: Exception) {
                Log.w(TAG, "Notification settings are unavailable", fallback)
            }
        }
        // 弹窗是异步的，这里只返回调用时的状态；页面回到前台时会重新读
        return isNotificationsEnabled()
    }

    override fun openAppSettings() {
        try {
            startIntent(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${context.packageName}"),
                ),
            )
        } catch (e: Exception) {
            Log.w(TAG, "Application settings are unavailable", e)
        }
    }

    override fun setSilentAudio(enabled: Boolean) {
        // 安卓没有静音音频保活，后台能否存活取决于上面的电池优化与通知权限
    }

    private fun openNotificationSettings() {
        startIntent(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
        )
    }

    // 有 Activity 时沿用它的任务栈，没有时才需要 NEW_TASK
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
        const val REQUEST_NOTIFICATIONS = 1001
    }
}
