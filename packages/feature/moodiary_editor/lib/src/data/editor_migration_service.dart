import 'dart:convert';
import 'dart:io';

import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:path/path.dart' as p;

/// 「迁移到 tiptap」服务：把旧的 richText(Quill Delta) 与 markdown 文本日记转换为 tiptap 文档 JSON。
///
/// - richText → JSON：[QuillDeltaToTiptap]（纯 Dart，直接产出节点树，图片/音频/视频还原为一等节点）。
/// - markdown → JSON：[MarkdownToTiptap]（纯 Dart，`markdown` 包 GFM 解析，无需无头 webview）。
/// - 转换后用 [DiaryContent]（tiptap 分支走 JSON 解析）重算 contentText 与媒体名，再经
///   [DiaryRepository.updateADiary] 落库（自动重建搜索索引）。媒体文件本身不动（文件名不变）。
/// - 迁移是纯本机行为：不 bump lastModified、不推送（多设备各自迁移）；回退则按真实编辑
///   对待（bump + 推送）。
/// - 可回退：转换前把原始 content + type 备份成 sidecar JSON（`migration_backup/<id>.json`）。
class EditorMigrationService {
  const EditorMigrationService._();

  static const String _backupType = 'migration_backup';

  static String _backupPath(String id) =>
      AppFiles.getRealPath(_backupType, '$id.json');

  static String _backupDir() => p.dirname(_backupPath('_'));

  static Future<void> _writeBackup(Diary diary) async {
    final path = _backupPath(diary.id);
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsString(
      jsonEncode({
        'id': diary.id,
        'content': diary.content,
        'type': diary.type,
        'savedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// 待迁移：所有非 tiptap 日记（richText + 旧 markdown，含回收站）。
  static Future<List<Diary>> pendingDiaries() async {
    final repo = DiaryRepository.get();
    final all = await repo.getAllDiaries(); // 含回收站
    return all
        .where((d) => DiaryType.fromValue(d.type) != DiaryType.tiptap)
        .toList();
  }

  /// 把一篇内容转成 tiptap JSON（不落库）。richText / markdown 均为纯 Dart。失败返回 null。
  static String? _toJson(Diary diary) {
    switch (DiaryType.fromValue(diary.type)) {
      case DiaryType.tiptap:
        return null; // 已是 tiptap
      case DiaryType.richText:
        return QuillDeltaToTiptap.convert(diary.content);
      case DiaryType.markdown:
        return MarkdownToTiptap.convert(diary.content);
    }
  }

  /// 迁移一篇：转 JSON → 备份原文 → 重算 contentText/媒体 → 落库为 tiptap。失败（解析失败）跳过、不动数据。
  static Future<bool> migrate(Diary diary) async {
    final json = _toJson(diary);
    if (json == null || json.isEmpty) return false;

    await _writeBackup(diary);

    final converted = diary.copyWith(content: json, type: DiaryType.tiptap.value);
    final media = DiaryContent.extractMedia(converted);
    final newDiary = converted.copyWith(
      contentText: DiaryContent.derivePlainText(converted),
      imageName: media.images,
      audioName: media.audios,
      videoName: media.videos,
    );
    // 迁移是纯本机的格式转换：不动 lastModified（LWW 两侧都不视为更新，批量迁移不会
    // 覆盖他端更新的编辑），事件走 fromSync（远端持有同时间戳的等价旧格式副本，不标
    // 脏、不触发推送）。多设备各自迁移一次；正文首次真实编辑后按普通编辑同步收敛。
    await DiaryRepository.get().updateADiary(newDiary: newDiary, fromSync: true);
    return true;
  }

  /// 批量迁移，逐篇回调进度。结束后释放无头转换 webview。
  static Future<MigrationReport> migrateAll(
    List<Diary> diaries, {
    void Function(int done, int total)? onProgress,
  }) async {
    var migrated = 0;
    var failed = 0;
    for (var i = 0; i < diaries.length; i++) {
      try {
        if (await migrate(diaries[i])) {
          migrated++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
      onProgress?.call(i + 1, diaries.length);
    }
    return MigrationReport(migrated: migrated, failed: failed);
  }

  /// 可回退列表：已备份（已迁移）的日记 id 及备份时间。
  static Future<List<MigrationBackup>> backups() async {
    final dir = Directory(_backupDir());
    if (!await dir.exists()) return [];
    final out = <MigrationBackup>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final data =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final id = data['id'];
        if (id is! String) continue;
        out.add(
          MigrationBackup(
            id: id,
            savedAt:
                DateTime.tryParse(data['savedAt'] as String? ?? '') ??
                DateTime.now(),
          ),
        );
      } catch (_) {
        /* 损坏的备份文件忽略 */
      }
    }
    out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return out;
  }

  /// 回退一篇：从备份还原原始 content 与 type（markdown/richText），删除备份。注意：迁移后对该篇的
  /// 编辑会被丢弃（还原为迁移前的内容）。
  static Future<bool> revert(String id) async {
    final file = File(_backupPath(id));
    if (!await file.exists()) return false;
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }
    final content = data['content'];
    if (content is! String) return false;
    final diary = await DiaryRepository.get().getDiaryByBusinessId(id);
    if (diary == null) {
      await file.delete();
      return false;
    }
    final restored = diary.copyWith(
      content: content,
      type: (data['type'] as String?) ?? DiaryType.richText.value,
    );
    final media = DiaryContent.extractMedia(restored);
    final newDiary = restored.copyWith(
      contentText: DiaryContent.derivePlainText(restored),
      imageName: media.images,
      audioName: media.audios,
      videoName: media.videos,
      // 与迁移不同，回退按真实内容编辑对待（bump + 正常推送）：弹窗已警告「迁移后的
      // 修改会丢失」。若不 bump，已推送过迁移后编辑的场景会留下同时间戳异内容的永久分歧。
      lastModified: DateTime.now(),
    );
    await DiaryRepository.get().updateADiary(newDiary: newDiary);
    await file.delete();
    return true;
  }
}

/// 批量迁移结果。
class MigrationReport {
  final int migrated;
  final int failed;
  const MigrationReport({required this.migrated, required this.failed});
}

/// 一条可回退备份。
class MigrationBackup {
  final String id;
  final DateTime savedAt;
  const MigrationBackup({required this.id, required this.savedAt});
}
