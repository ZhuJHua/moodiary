package cn.yooss.moodiary_native

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

// 安卓侧只负责电池优化白名单，真正的常驻/保活不由这里实现
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

    override fun setSilentAudio(enabled: Boolean) {
        // 安卓没有静音音频保活，开关只负责申请白名单
    }

    private companion object {
        const val TAG = "BackgroundKeepAlive"
    }
}
