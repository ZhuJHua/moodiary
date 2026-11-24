package cn.yooss.moodiary_native

import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

class MoodiaryNativePlugin : FlutterPlugin, ActivityAware, PluginRegistry.NewIntentListener {
    private var keyboard: KeyboardHeight? = null
    private var keepAlive: BackgroundKeepAlive? = null
    private var keepAliveEvents: BackgroundKeepAliveEvents? = null
    private var permission: NotificationPermission? = null
    private var location: DeviceLocation? = null
    private var reminders: ReminderNotifications? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        keepAliveEvents = BackgroundKeepAliveEvents(messenger).also {
            McpKeepAliveService.events = it
        }
        HtmlClipboardApi.setUp(messenger, HtmlClipboard(binding.applicationContext))
        ImageTransferApi.setUp(messenger, ImageTransfer(binding.applicationContext))
        keyboard = KeyboardHeight().also { KeyboardHeightStreamHandler.register(messenger, it) }
        keepAlive = BackgroundKeepAlive(binding.applicationContext).also {
            BackgroundKeepAliveApi.setUp(messenger, it)
        }
        permission = NotificationPermission(binding.applicationContext).also {
            NotificationPermissionApi.setUp(messenger, it)
        }
        location = DeviceLocation(binding.applicationContext).also {
            LocationApi.setUp(messenger, it)
        }
        reminders = ReminderNotifications(binding.applicationContext, ReminderNotificationsEvents(messenger)).also {
            ReminderNotificationsApi.setUp(messenger, it)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        if (McpKeepAliveService.events === keepAliveEvents) {
            McpKeepAliveService.events = null
        }
        keepAliveEvents = null
        HtmlClipboardApi.setUp(messenger, null)
        ImageTransferApi.setUp(messenger, null)
        BackgroundKeepAliveApi.setUp(messenger, null)
        NotificationPermissionApi.setUp(messenger, null)
        LocationApi.setUp(messenger, null)
        ReminderNotificationsApi.setUp(messenger, null)
        onDetachedFromActivity()
        reminders?.detach()
        reminders = null
        permission = null
        location = null
        keyboard = null
        keepAlive = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        setActivity(binding)
        binding.addOnNewIntentListener(this)
        permission?.let { binding.addRequestPermissionsResultListener(it) }
        location?.let { binding.addRequestPermissionsResultListener(it) }
        binding.activity.intent?.let { onNewIntent(it) }
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeOnNewIntentListener(this)
        permission?.let { activityBinding?.removeRequestPermissionsResultListener(it) }
        location?.let { activityBinding?.removeRequestPermissionsResultListener(it) }
        setActivity(null)
    }

    override fun onDetachedFromActivity() {
        onDetachedFromActivityForConfigChanges()
        permission?.finish(false)
        location?.finish()
    }

    override fun onNewIntent(intent: Intent): Boolean {
        if (reminders?.takeTap(intent) != true) return false
        activityBinding?.activity?.intent = Intent(intent)
        return true
    }

    private fun setActivity(binding: ActivityPluginBinding?) {
        activityBinding = binding
        val activity = binding?.activity
        permission?.activity = activity
        location?.activity = activity
        keyboard?.activity = activity
        keepAlive?.activity = activity
    }
}
