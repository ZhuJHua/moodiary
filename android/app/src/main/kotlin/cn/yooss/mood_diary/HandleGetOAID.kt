package cn.yooss.mood_diary

import com.github.gzuliyujiang.oaid.IGetter
import io.flutter.plugin.common.MethodChannel
import java.lang.Exception

class HandleGetOAID(private var resultCallback: MethodChannel.Result) : IGetter {
    override fun onOAIDGetComplete(result: String?) {
        resultCallback.success(result);
    }

    override fun onOAIDGetError(error: Exception?) {

        resultCallback.error("100", "error", error);
    }
}