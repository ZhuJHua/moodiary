import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

/// 读音频文件时长：audio_metadata_reader 按内容识别容器（不看扩展名）、只读
/// 头部不解码。解析失败返回 null——导入路径以此为闸门（认不出的文件不允许
/// 添加）；录音路径认不出时回落录制计时。
///
/// 后端取舍（2026-08-11 定论）：曾用 Rust lofty，多付 1MB+ 二进制体积；实测
/// 历史「假 .m4a」老录音 lofty 同样读不出（文件本身损坏），纯 Dart 方案没有
/// 能力差距，故按体积取舍回到本实现。
Future<Duration?> probeAudioDuration(String path) {
  return Isolate.run(() {
    try {
      final duration = readMetadata(File(path)).duration;
      if (duration == null || duration <= Duration.zero) return null;
      return duration;
    } catch (_) {
      return null;
    }
  });
}
