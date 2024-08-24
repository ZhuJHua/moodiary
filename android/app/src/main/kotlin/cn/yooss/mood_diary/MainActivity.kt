package cn.yooss.mood_diary

import android.graphics.Color
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import com.github.gzuliyujiang.oaid.DeviceID
import com.tencent.shiply.processor.DiffPkgHandler
import com.tencent.shiply.processor.OriginBasePkgFile
import com.tencent.upgrade.bean.UpgradeConfig
import com.tencent.upgrade.core.UpgradeManager
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
            flutterEngine.dartExecutor.binaryMessenger, "shiply_channel"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initShiply" -> {
                    initShiply()
                    result.success(null)
                }


                "checkUpdate" -> {
                    checkUpdate(result)
                }

                "startDownload" -> {
                    startDownload()
                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
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


    private fun checkUpdate(result: MethodChannel.Result) {
        UpgradeManager.getInstance().checkUpgrade(true, null, HandleUpgradeCallback(result))
    }

    private fun startDownload() {
        UpgradeManager.getInstance().startDownload()
    }

    private fun initShiply() {
        val builder: UpgradeConfig.Builder = UpgradeConfig.Builder()
        val config: UpgradeConfig =
            builder.appId("").appKey("")
                .diffPkgHandler(DiffPkgHandler()).basePkgFileForDiffUpgrade(OriginBasePkgFile())
                .cacheExpireTime(1000 * 60 * 60 * 6).userId("").build()
        UpgradeManager.getInstance().init(application, config)
    }

    private fun getOAID(resultCallback: MethodChannel.Result) {
        if (DeviceID.supportedOAID(application)) {
            DeviceID.getOAID(application, HandleGetOAID(resultCallback));
        }
    }

    private fun setSystemUIVisibility() {
        val windowInsetsController = ViewCompat.getWindowInsetsController(window.decorView)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        //window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.navigationBarColor = Color.TRANSPARENT
    }

}
