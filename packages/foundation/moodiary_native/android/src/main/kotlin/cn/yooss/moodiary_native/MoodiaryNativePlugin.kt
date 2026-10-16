package cn.yooss.moodiary_native

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

class MoodiaryNativePlugin : FlutterPlugin, ActivityAware {
    private var keyboard: EditorKeyboard? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        SelectionHandleApi.setUp(messenger, SelectionHandleDrawable)
        keyboard = EditorKeyboard(binding).also {
            EditorKeyboardApi.setUp(messenger, it)
            KeyboardEventsStreamHandler.register(messenger, it.events)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        SelectionHandleApi.setUp(messenger, null)
        EditorKeyboardApi.setUp(messenger, null)
        keyboard?.dispose()
        keyboard = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = setActivity(binding.activity)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        setActivity(binding.activity)

    override fun onDetachedFromActivityForConfigChanges() = setActivity(null)

    override fun onDetachedFromActivity() = setActivity(null)

    private fun setActivity(activity: Activity?) {
        keyboard?.activity = activity
    }
}
