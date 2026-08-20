import 'dart:convert';
import 'dart:io';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;

/// 强制迁移服务：把旧的 richText(Quill Delta) 与 markdown 文本日记转换为 tiptap 文档 JSON。
/// 2.8.0 起迁移是启动闸门（见 app 路由的 redirect）：存在旧格式日记就进不了主界面。
///
/// - richText → JSON：[QuillDeltaToTiptap]；markdown → JSON：[MarkdownToTiptap]。均为纯 Dart。
/// - **迁移是全函数**：转换失败逐级降级到纯文本包装（宁可掉格式不丢字），闸门因此必然收敛。
/// - **媒体守恒**：[TiptapContent.ensureMedia] 保证迁移后的媒体字段 ⊇ 迁移前
///   （缩进整篇成代码块、≤2.4 附件式媒体不在正文里等场景，引用只增不减，
///   否则「清理无用文件」会把真实文件当孤儿删掉）。
/// - **可断点续跑**：逐篇独立事务，转换前先写 sidecar 备份（`migration_backup/<id>.json`）；
///   中途杀进程只留一份多余备份，已迁移的不再入列，下次启动闸门重新收敛。
/// - 迁移是纯本机行为：不 bump lastModified、事件走 fromSync（多设备各自迁移，
///   LWW 两侧都不视为更新）。
class EditorMigrationService {
  const EditorMigrationService._();

  /// 启动闸门：存在旧格式日记时为 true，路由 redirect 据此把一切页面重定向到迁移页。
  /// 由组合根在版本迁移后 [refreshRequiresMigration] 置位，迁移页完成后清零。
  static bool requiresMigration = false;

  static Future<void> refreshRequiresMigration() async {
    requiresMigration = await DiaryRepository.get().hasLegacyFormatDiaries();
  }

  static const String _backupType = 'migration_backup';

  static String _backupPath(String id) =>
      AppFiles.getRealPath(_backupType, '$id.json');

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
  static Future<List<Diary>> pendingDiaries() =>
      DiaryRepository.get().getLegacyFormatDiaries();

  /// 一篇内容 → tiptap JSON。逐级降级、必然产出合法文档：
  /// 转换器 → 纯文本再走 markdown 解析（与只读渲染路径一致）→ 逐行包段落。
  static String _toJson(Diary diary) {
    switch (DiaryType.fromValue(diary.type)) {
      case .tiptap:
        return diary.content;
      case .richText:
        final converted = QuillDeltaToTiptap.convert(diary.content);
        if (converted != null) return converted;
        // 不是合法 Delta（极老版本的裸文本残留）：与 EditorBody 的只读渲染同一条兜底链。
        // plainText 对「恰好是 JSON 数组的裸文本」会给出空串（op 全非 Map 被跳过），
        // 原文非空而提取为空时回退原文——强制迁移里一个字都不能静默丢。
        var plain = QuillDelta.plainText(diary.content) ?? diary.content;
        if (plain.trim().isEmpty && diary.content.trim().isNotEmpty) {
          plain = diary.content;
        }
        return MarkdownToTiptap.convert(plain) ??
            TiptapContent.wrapPlainText(plain);
      case .markdown:
        return MarkdownToTiptap.convert(diary.content) ??
            TiptapContent.wrapPlainText(diary.content);
    }
  }

  /// 迁移一篇：转 JSON（必成）→ 媒体守恒 → 备份原文 → 重算 contentText/媒体 → 落库。
  /// 已是 tiptap 返回 false（无事可做）。
  static Future<bool> migrate(Diary diary) async {
    if (DiaryType.fromValue(diary.type) == .tiptap) return false;
    final json = TiptapContent.ensureMedia(
      _toJson(diary),
      images: diary.imageName,
      audios: diary.audioName,
      videos: diary.videoName,
    );

    await _writeBackup(diary);

    final converted = diary.copyWith(
      content: json,
      type: DiaryType.tiptap.value,
    );
    final derived = DiaryContent.of(converted);
    final media = derived.media;
    final newDiary = converted.copyWith(
      contentText: derived.plainText,
      imageName: media.images,
      audioName: media.audios,
      videoName: media.videos,
    );
    // 不动 lastModified（LWW 两侧都不视为更新，批量迁移不会覆盖他端更新的编辑），
    // 事件走 fromSync（远端持有同时间戳的等价旧格式副本，不标脏、不触发推送）。
    // 索引：升级用户的倒排本就是空的、等「重建索引」一次性回填，逐篇 inline 会让
    // posting 行随已迁移篇数线性变长地整行重写（O(N²)），skip 掉；已回填过的
    // （多设备 pull 带回旧格式行的窄场景）保持 inline，迁移完即可搜。
    await DiaryRepository.get().updateADiary(
      newDiary: newDiary,
      fromSync: true,
      index: MoodiaryKVs.searchIndexBackfilled.get() ?? false ? .inline : .skip,
    );
    return true;
  }

  /// 批量迁移，逐篇回调进度。逐篇独立事务，抛错计 failed 继续，可整体重跑。
  static Future<MigrationReport> migrateAll(
    List<Diary> diaries, {
    void Function(int done, int total)? onProgress,
  }) async {
    var migrated = 0;
    var failed = 0;
    for (var i = 0; i < diaries.length; i++) {
      try {
        if (await migrate(diaries[i])) migrated++;
      } catch (e, s) {
        logger.e('migrate diary failed', error: e, stackTrace: s);
        failed++;
      }
      onProgress?.call(i + 1, diaries.length);
    }
    return MigrationReport(migrated: migrated, failed: failed);
  }
}

/// 批量迁移结果。[failed] 只计 I/O / 落库异常——格式转换本身必成（逐级兜底）。
class MigrationReport {
  final int migrated;
  final int failed;
  const MigrationReport({required this.migrated, required this.failed});
}
