package cn.yooss.mood_diary

import com.google.gson.Gson
import com.tencent.upgrade.bean.UpgradeStrategy
import com.tencent.upgrade.callback.UpgradeStrategyRequestCallback
import io.flutter.plugin.common.MethodChannel

/**
 * @Description
 * @Author 住京华 https://yooss.cn
 * @Date 2024/6/11
 */
class HandleUpgradeCallback(private var result: MethodChannel.Result) :
    UpgradeStrategyRequestCallback {

    override fun onReceiveStrategy(var1: UpgradeStrategy) {

        result.success(Gson().toJson(var1));
    }

    override fun onFail(var1: Int, var2: String) {

    }

    override fun onReceivedNoStrategy() {
        result.success(null)
    }

}