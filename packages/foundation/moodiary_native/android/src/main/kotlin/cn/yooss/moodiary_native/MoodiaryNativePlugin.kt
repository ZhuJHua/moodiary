package cn.yooss.moodiary_native

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

class MoodiaryNativePlugin : FlutterPlugin, ActivityAware {
    private var keyboard: KeyboardHeight? = null
    private var keepAlive: BackgroundKeepAlive? = null
    private var keepAliveEvents: BackgroundKeepAliveEvents? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        keepAliveEvents = BackgroundKeepAliveEvents(messenger).also {
            McpKeepAliveService.events = it
        }
        HtmlClipboardApi.setUp(messenger, HtmlClipboard(binding.applicationContext))
        LocalTimeZoneApi.setUp(messenger, LocalTimeZone())
        ImageTransferApi.setUp(messenger, ImageTransfer(binding.applicationContext))
        keyboard = KeyboardHeight().also { KeyboardHeightStreamHandler.register(messenger, it) }
        keepAlive = BackgroundKeepAlive(binding.applicationContext).also {
            BackgroundKeepAliveApi.setUp(messenger, it)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        if (McpKeepAliveService.events === keepAliveEvents) {
            McpKeepAliveService.events = null
        }
        keepAliveEvents = null
        HtmlClipboardApi.setUp(messenger, null)
        LocalTimeZoneApi.setUp(messenger, null)
        ImageTransferApi.setUp(messenger, null)
        BackgroundKeepAliveApi.setUp(messenger, null)
        keyboard?.activity = null
        keyboard = null
        keepAlive = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = setActivity(binding.activity)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        setActivity(binding.activity)

    override fun onDetachedFromActivityForConfigChanges() = setActivity(null)

    override fun onDetachedFromActivity() = setActivity(null)

    private fun setActivity(activity: Activity?) {
        keyboard?.activity = activity
        keepAlive?.activity = activity
    }
}
