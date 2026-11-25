package cn.yooss.moodiary_native

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CompletableDeferred

internal class NotificationPermission(private val context: Context) : NotificationPermissionApi,
    PluginRegistry.RequestPermissionsResultListener {
    var activity: Activity? = null
    private var pending: CompletableDeferred<Boolean>? = null
    private val manager = requireNotNull(context.getSystemService(NotificationManager::class.java))

    override suspend fun isEnabled() = manager.areNotificationsEnabled()

    override suspend fun request(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return isEnabled()
        val host = activity ?: return false
        pending?.let { return it.await() }
        if (isEnabled()) return true
        val result = CompletableDeferred<Boolean>()
        pending = result
        try {
            ActivityCompat.requestPermissions(host, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE)
        } catch (error: Exception) {
            pending = null
            result.completeExceptionally(error)
        }
        return result.await()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val index = permissions.indexOf(Manifest.permission.POST_NOTIFICATIONS)
        finish(grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED && manager.areNotificationsEnabled())
        return true
    }

    fun finish(granted: Boolean) {
        val result = pending
        pending = null
        result?.complete(granted)
    }

    override fun openSettings() {
        try {
            start(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName))
        } catch (_: ActivityNotFoundException) {
            start(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")))
        }
    }

    private fun start(intent: Intent) {
        activity?.startActivity(intent) ?: context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private companion object {
        const val REQUEST_CODE = 0x4d52
    }
}
