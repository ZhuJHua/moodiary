package cn.yooss.moodiary_native

import io.flutter.embedding.engine.plugins.FlutterPlugin

class MoodiaryNativePlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        SelectionHandleApi.setUp(binding.binaryMessenger, SelectionHandleDrawable)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        SelectionHandleApi.setUp(binding.binaryMessenger, null)
    }
}
