package cn.yooss.moodiary

import android.media.MediaCodecList
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.renderer.FlutterRenderer

class MainActivity : FlutterFragmentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    // Avoid HiSilicon AVC failures with ImageReader; Flutter's workaround only covers API <= 29.
    // Set before engine initialization. See https://github.com/flutter/flutter/issues/188560
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
