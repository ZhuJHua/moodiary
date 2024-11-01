package cn.yooss.mood_diary

import android.os.Build
import androidx.activity.enableEdgeToEdge
import androidx.annotation.RequiresApi
import androidx.core.view.WindowCompat
import com.github.gzuliyujiang.oaid.DeviceID
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterFragmentActivity() {


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "view_channel"
        ).setMethodCallHandler { call, result ->
            if (call.method == "setSystemUIVisibility") {
                setSystemUIVisibility()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
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

    private fun setSystemUIVisibility() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        enableEdgeToEdge()
    }

}
