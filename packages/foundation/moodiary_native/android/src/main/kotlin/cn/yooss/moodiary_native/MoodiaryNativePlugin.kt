package cn.yooss.moodiary_native

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

class MoodiaryNativePlugin : FlutterPlugin, ActivityAware {
    private var imageTransfer: ImageTransfer? = null
    private var keyboard: KeyboardHeight? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        HtmlClipboardApi.setUp(messenger, HtmlClipboard(binding.applicationContext))
        imageTransfer = ImageTransfer(binding.applicationContext, messenger).also {
            ImageTransferApi.setUp(messenger, it)
        }
        keyboard = KeyboardHeight().also { KeyboardHeightStreamHandler.register(messenger, it) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        HtmlClipboardApi.setUp(messenger, null)
        ImageTransferApi.setUp(messenger, null)
        imageTransfer?.dispose()
        imageTransfer = null
        keyboard?.activity = null
        keyboard = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = setActivity(binding.activity)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        setActivity(binding.activity)

    override fun onDetachedFromActivityForConfigChanges() = setActivity(null)

    override fun onDetachedFromActivity() = setActivity(null)

    private fun setActivity(activity: Activity?) {
        imageTransfer?.activity = activity
        keyboard?.activity = activity
    }
}
