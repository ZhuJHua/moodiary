import 'dart:io';

import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';

/// 用户自定义人格（SOUL），存为 `<applicationSupport>/assistant/SOUL.md`；
/// 仅设备本地，不进备份/同步。
class SoulRepository {
  SoulRepository._();

  factory SoulRepository.get() => _instance;

  static final SoulRepository _instance = SoulRepository._();

  String get _path => AppFiles.getRealPath('assistant', 'SOUL.md');

  /// 读取生效人格：文件存在读文件，否则回退 [defaultSoul]；始终非空（保持缓存前缀稳定）。
  Future<String> read() async {
    final file = File(_path);
    if (!await file.exists()) return defaultSoul;
    try {
      final content = await file.readAsString();
      return content.trim().isEmpty ? defaultSoul : content;
    } catch (_) {
      return defaultSoul;
    }
  }

  /// 是否已由用户定制（文件存在）。
  Future<bool> isCustomized() => File(_path).exists();

  /// 保存自定义人格。超出 [soulMaxChars] 的部分截断；空内容视为重置为默认。
  Future<void> write(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      await resetToDefault();
      return;
    }
    final capped = trimmed.length > soulMaxChars
        ? trimmed.substring(0, soulMaxChars)
        : trimmed;
    final file = File(_path);
    await file.parent.create(recursive: true);
    await file.writeAsString(capped, flush: true);
  }

  /// 重置为出厂默认：删除文件（read() 随即回退到 [defaultSoul]）。
  Future<void> resetToDefault() async {
    final file = File(_path);
    if (await file.exists()) await file.delete();
  }
}
