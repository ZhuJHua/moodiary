package cn.yooss.mood_diary

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import com.github.gzuliyujiang.oaid.DeviceID
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "oaid_channel"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getOAID" -> {
                    getOAID(result)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

    }

    private fun getOAID(resultCallback: MethodChannel.Result) {
        if (DeviceID.supportedOAID(application)) {
            DeviceID.getOAID(application, HandleGetOAID(resultCallback));
        }
    }

}
