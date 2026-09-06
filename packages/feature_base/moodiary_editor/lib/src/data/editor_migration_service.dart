import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;

class EditorMigrationService {
  const EditorMigrationService._();

  static bool requiresMigration = false;

  static Future<void> refreshRequiresMigration() async {
    requiresMigration = await getIt<DiaryRepository>().hasLegacyFormatDiaries();
    if (!requiresMigration) unawaited(purgeBackups());
  }

  static const String _backupType = 'migration_backup';

  static String _backupPath(String id) =>
      AppFiles.getRealPath(_backupType, '$id.json');

  static String get backupDirPath => AppFiles.getRealPath(_backupType, '');

  static Future<void> purgeBackups() async {
    try {
      await AppFiles.deleteDir(backupDirPath);
    } catch (e, s) {
      logger.e('purge migration backups failed', error: e, stackTrace: s);
    }
  }

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

  static Future<List<Diary>> pendingDiaries() =>
      getIt<DiaryRepository>().getLegacyFormatDiaries();

  static String _toJson(Diary diary) {
    switch (DiaryType.fromValue(diary.type)) {
      case .tiptap:
        return diary.content;
      case .richText:
        final converted = QuillDeltaToTiptap.convert(diary.content);
        if (converted != null) return converted;
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
    await getIt<DiaryRepository>().updateADiary(
      newDiary: newDiary,
      fromSync: true,
      index: MoodiaryKVs.searchIndexBackfilled.get() ?? false ? .inline : .skip,
    );
    return true;
  }

  static String redactDbError(Object error) {
    var text = error.toString();
    var cut = text.length;
    for (final marker in const [
      'Causing statement',
      ', parameters:',
      'parameters:',
    ]) {
      final i = text.indexOf(marker);
      if (i >= 0 && i < cut) cut = i;
    }
    text = text.substring(0, cut).trimRight();
    const limit = 500;
    if (text.length > limit) text = '${text.substring(0, limit)}…[truncated]';
    return text;
  }

  static Future<MigrationReport> migrateAll(
    List<Diary> diaries, {
    void Function(int done, int total)? onProgress,
  }) async {
    var migrated = 0;
    final failures = <MigrationFailure>[];
    for (var i = 0; i < diaries.length; i++) {
      try {
        if (await migrate(diaries[i])) migrated++;
      } catch (e, s) {
        final redacted = redactDbError(e);
        logger.e('migrate diary failed', error: redacted, stackTrace: s);
        failures.add(
          MigrationFailure(
            diaryId: diaries[i].id,
            error: redacted,
            stackTrace: s.toString(),
          ),
        );
      }
      onProgress?.call(i + 1, diaries.length);
    }
    return MigrationReport(migrated: migrated, failures: failures);
  }
}

class MigrationReport {
  final int migrated;
  final List<MigrationFailure> failures;
  const MigrationReport({required this.migrated, required this.failures});

  int get failed => failures.length;
}

class MigrationFailure {
  final String diaryId;
  final String error;
  final String stackTrace;
  const MigrationFailure({
    required this.diaryId,
    required this.error,
    required this.stackTrace,
  });
}
