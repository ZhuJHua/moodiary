package cn.yooss.moodiary

import android.media.MediaCodecList
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.renderer.FlutterRenderer

/**
 * 海思解码器机型上，引擎给外部纹理用的 `ImageReader` 只有 `MAX_IMAGES = 7` 张 buffer，
 * 海思 OMX 上屏却要 12 张，协商失败后解码器进 ERROR 态，视频建不起来。
 *
 * 引擎为此准备了 `hasAndroidHardwareBufferDefect()`：外部纹理改走没有 maxImages 上限的
 * `SurfaceTexture`。但它只认 `SDK_INT <= 29 && HUAWEI`，API 30+ 的同款机型被漏掉，这里
 * 按"机器上确实有海思 H.264 解码器"补齐。
 */
class MainActivity : FlutterFragmentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    // 必须早于 super.onCreate：引擎在 super 里创建，纹理实现是建纹理时按这个开关选的。
    if (Build.VERSION.SDK_INT > 29 && hasHiSiliconAvcDecoder) {
      FlutterRenderer.debugForceSurfaceProducerGlTextures = true
    }
    super.onCreate(savedInstanceState)
  }

  private val hasHiSiliconAvcDecoder: Boolean by lazy {
    runCatching {
      MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.any { codec ->
        codec.name.contains("hisi", true) &&
          codec.supportedTypes.any { it.equals("video/avc", true) }
      }
    }.getOrDefault(false)
  }
}
