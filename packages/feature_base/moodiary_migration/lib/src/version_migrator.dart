import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' hide Category;
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_migration/src/legacy/legacy_models.dart' as legacy;
import 'package:moodiary_migration/src/orphan_media_cleaner.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:pub_semver/pub_semver.dart';

final _schemas = legacy.legacyMigrationSchemas;

class VersionMigrator {
  static Future<void> run() async {
    if (MmkvKVStorage.legacyMigrationPending) return;
    final packageInfo = await AppInfo.getPackageInfo();
    await apply(
      currentVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
    );
  }

  @visibleForTesting
  static Future<void> apply({required String currentVersion}) async {
    final appVersion = MoodiaryKVs.appVersion.get();
    if (appVersion != null) {
      await merge(lastAppVersion: appVersion);
    }
    if (appVersion == null) {
      MoodiaryKVs.searchIndexBackfilled.set(true);
      MoodiaryKVs.contentSchemaV2.set(true);
    }
    if (kDebugMode || appVersion == null || appVersion != currentVersion) {
      MoodiaryKVs.appVersion.set(currentVersion);
    }
  }

  @visibleForTesting
  static bool versionBelow(String lastAppVersion, String gate) {
    final parsed = Version.parse(lastAppVersion);
    final normalized = Version(parsed.major, parsed.minor, parsed.patch);
    return normalized < Version.parse(gate);
  }

  static Future<void> merge({required String lastAppVersion}) async {
    bool below(String version) => versionBelow(lastAppVersion, version);

    String? dirCache;
    String dir() => dirCache ??= AppFiles.getRealPath('database', '');

    bool? legacyCache;
    bool hasLegacyDb() => legacyCache ??= legacy.legacyDbExistsIn(dir());

    if (below('2.4.8') && hasLegacyDb()) {
      await compute(_mergeToV2_4_8, dir());
    }

    if (below('2.6.0') && hasLegacyDb()) {
      await compute(_mergeToV2_6_0, dir());
    }

    if (below('2.6.2')) {
      await MediaManager.regenerateMissingThumbnails();
    }

    if (below('2.6.3')) {
      await cleanOrphanMediaIn(dir());
      await MediaManager.regenerateMissingThumbnails();
      if (hasLegacyDb()) await compute(_fixV2_6_3, dir());
    }

    if (below('2.7.3')) {
      MoodiaryKVs.customFont.set('');
      if (hasLegacyDb()) {
        final allFont = await getIt<FontRepository>().scanDiskFonts();
        await compute(_mergeToV2_7_3, {
          'database': dir(),
          'fonts': [
            for (final font in allFont)
              legacy.Font(
                fontFileName: font.fontFileName,
                fontWghtAxisMap: font.fontWghtAxisMap,
              ),
          ],
        });
      }
    }

    if (below('2.8.0')) {
      MoodiaryKVs.autoSync.set(false);
      if (hasLegacyDb()) {
        await _backupDatabaseOnce();
        await compute(_mergeToV2_8_0, dir());
      }
    }

    if (below('2.8.2') && MoodiaryKVs.assistantReasoningEffort.get() == '') {
      MoodiaryKVs.assistantReasoningEffort.set('none');
    }

    if (below('2.9.1')) {
      await _purgeMoodLlmModel();
    }
  }

  @visibleForTesting
  static void debugMergeToV280(String dir) => _mergeToV2_8_0(dir);

  @visibleForTesting
  static void debugMergeToV260(String dir) => _mergeToV2_6_0(dir);

  @visibleForTesting
  static void debugFixV263(String dir) => _fixV2_6_3(dir);

  @visibleForTesting
  static Future<void> debugMergeToV273(String dir, List<legacy.Font> fonts) =>
      _mergeToV2_7_3({'database': dir, 'fonts': fonts});
}

Future<void> _purgeMoodLlmModel() async {
  for (final name in const [
    'qwen3-0.6b-int8.onnx',
    'qwen3-0.6b-int8.tokenizer.json',
    'qwen3-0.6b-int8.onnx.part',
    'qwen3-0.6b-int8.tokenizer.json.part',
  ]) {
    try {
      await AppFiles.deleteFile(AppFiles.getRealPath('model', name));
    } catch (e, s) {
      logger.e('purge mood model failed: $name', error: e, stackTrace: s);
    }
  }
  try {
    getIt<IKVStorage>().remove('moodLlmModelId');
  } catch (e, s) {
    logger.e('remove mood model key failed', error: e, stackTrace: s);
  }
}

Future<void> _backupDatabaseOnce() async {
  try {
    final src = File(AppFiles.getRealPath('database', 'default.isar'));
    final dst = AppFiles.getRealPath('database', 'default.isar.v273bak');
    if (await src.exists() && !(await File(dst).exists())) {
      await src.copy(dst);
    }
  } catch (_) {
    // 备份失败不阻断迁移
  }
}

void _mergeToV2_4_8(String dir) {
  final isar = legacy.openLegacyIsar(schemas: _schemas, dir: dir);
  if (isar == null) return;
  try {
    final countDiary = isar.diarys.where().count();
    for (var i = 0; i < countDiary; i += 50) {
      final diaries = isar.diarys.where().findAll(offset: i, limit: 50);
      isar.write((isar) {
        isar.diarys.putAll(diaries);
      });
    }
  } finally {
    isar.close();
  }
}

void _mergeToV2_6_0(String dir) {
  final isar = legacy.openLegacyIsar(schemas: _schemas, dir: dir);
  if (isar == null) return;
  try {
    final countDiary = isar.diarys.where().count();

    for (var i = 0; i < countDiary; i += 50) {
      final diaries = isar.diarys.where().findAll(offset: i, limit: 50);

      isar.write((isar) {
        for (final diary in diaries) {
          final lastModified = diary.time;
          final content = QuillDelta.isDelta(diary.content)
              ? diary.content
              : QuillDelta.wrapPlainText(diary.content);

          isar.diarys.put(
            diary.copyWith(
              content: content,
              type: DiaryType.richText.value,
              lastModified: lastModified,
              time: lastModified,
            ),
          );
        }
      });
    }
  } finally {
    isar.close();
  }
}

void _fixV2_6_3(String dir) {
  final isar = legacy.openLegacyIsar(schemas: _schemas, dir: dir);
  if (isar == null) return;
  try {
    final countDiary = isar.diarys.where().count();
    for (var i = 0; i < countDiary; i += 50) {
      final diaries = isar.diarys.where().findAll(offset: i, limit: 50);
      isar.write((isar) {
        for (final diary in diaries) {
          final id = diary.categoryId;
          if (id != null && isar.categorys.where().idEqualTo(id).isEmpty()) {
            isar.categorys.put(
              legacy.Category(
                id: id,
                // compute isolate 内原生库未必装载，不能走 Rust 侧 uuid，退化用随机 hex。
                categoryName:
                    '已修复${Random().nextInt(0x10000).toRadixString(16).padLeft(4, '0')}',
                lastModified: diary.lastModified,
                parentId: null,
              ),
            );
          }
        }
      });
    }
  } finally {
    isar.close();
  }
}

Future<void> _mergeToV2_7_3(Map<String, dynamic> parma) async {
  final isar = legacy.openLegacyIsar(
    schemas: _schemas,
    dir: parma['database']!,
  );
  if (isar == null) return;
  try {
    await isar.writeAsync((isar) {
      isar.fonts.clear();
      isar.fonts.putAll(parma['fonts']);
    });
  } finally {
    isar.close();
  }
}

void _mergeToV2_8_0(String dir) {
  const legacyTextType = 'text';
  final isar = legacy.openLegacyIsar(schemas: _schemas, dir: dir);
  if (isar == null) return;
  try {
    final countDiary = isar.diarys.where().count();
    for (var i = 0; i < countDiary; i += 50) {
      final diaries = isar.diarys.where().findAll(offset: i, limit: 50);

      isar.write((isar) {
        for (final diary in diaries) {
          var content = diary.content;
          var type = diary.type;
          if (type == legacyTextType) {
            if (!QuillDelta.isDelta(content)) {
              content = QuillDelta.wrapPlainText(content);
            }
            type = DiaryType.richText.value;
          }

          isar.diarys.put(diary.copyWith(content: content, type: type));
        }
      });
    }
  } finally {
    isar.close();
  }
}
