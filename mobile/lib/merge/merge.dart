import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:pub_semver/pub_semver.dart';

final _schemas = [DiarySchema, CategorySchema, FontSchema];

class MergeUtil {
  /// 版本号比对触发数据迁移钩子并写回当前版本号。须在 KV / Isar 初始化后由组合根
  /// （`main.dart`）调用——此前内联在 `SharedPreferencesKVStorage.init`，现上移以解除
  /// core → merge 反向依赖。
  static Future<void> runVersionMigration() async {
    final packageInfo = await PackageUtil.getPackageInfo();
    final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final appVersion = MoodiaryKVs.appVersion.get();
    if (appVersion != null) {
      await merge(lastAppVersion: appVersion);
    }
    // 全文 / 双链倒排索引首次引入于 2.8.0：全新安装（appVersion==null）的新日记走增量索引，
    // 直接置「已回填」，免搜索页的升级提示；从旧版升级则保持 false，由提示引导用户手动重建一次。
    if (appVersion == null) {
      await MoodiaryKVs.searchIndexBackfilled.set(true);
    }
    if (kDebugMode || appVersion == null || appVersion != currentVersion) {
      await MoodiaryKVs.appVersion.set(currentVersion);
    }
  }

  static Future<void> merge({required String lastAppVersion}) async {
    // 语义化版本比较：`2.10.0 > 2.9.0` 这类按字典序会判错的场景必须走 semver。
    // 入参形如 `2.7.3+123`（version+build），build 元数据在 semver 比较中被忽略。
    final lastVersion = Version.parse(lastAppVersion);
    bool below(String version) => lastVersion < Version.parse(version);

    if (below('2.4.8')) {
      await compute(
        _mergeToV2_4_8,
        FileUtil.getRealPath('database', ''),
      );
    }

    if (below('2.6.0')) {
      await compute(
        _mergeToV2_6_0,
        FileUtil.getRealPath('database', ''),
      );
    }

    if (below('2.6.2')) {
      await MediaUtil.regenerateMissingThumbnails();
    }

    if (below('2.6.3')) {
      await FileUtil.cleanFile(FileUtil.getRealPath('database', ''));
      await MediaUtil.regenerateMissingThumbnails();
      await compute(_fixV2_6_3, FileUtil.getRealPath('database', ''));
    }

    if (below('2.7.3')) {
      await MoodiaryKVs.customFont.set('');
      final allFont = await FontUtil.getAllFonts();
      await compute(_mergeToV2_7_3, {
        'database': FileUtil.getRealPath('database', ''),
        'fonts': allFont,
      });
    }

    if (below('2.8.0')) {
      // 跨引擎（isar 4.0.0-dev → isar_plus）迁移前留一份快照，出问题可回滚。
      await _backupDatabaseOnce();
      await compute(
        _mergeToV2_8_0,
        FileUtil.getRealPath('database', ''),
      );
    }
  }
}

/// 2.8.0 迁移前对数据库文件做一次性快照备份（`default.isar.v273bak`）：跨引擎迁移 / 写回
/// 若出问题可回滚。已存在备份或库文件缺失则跳过；备份失败仅跳过、不阻断迁移。
Future<void> _backupDatabaseOnce() async {
  try {
    final src = File(FileUtil.getRealPath('database', 'default.isar'));
    final dst = FileUtil.getRealPath('database', 'default.isar.v273bak');
    if (await src.exists() && !(await File(dst).exists())) {
      await src.copy(dst);
    }
  } catch (_) {
    // 备份失败不阻断迁移（迁移本身对既有数据幂等）。
  }
}

/// 2.4.8 升级：重写日记记录，更新部分字段。
void _mergeToV2_4_8(String dir) {
  final isar = Isar.open(schemas: _schemas, directory: dir);
  final countDiary = isar.diarys.where().count();
  for (var i = 0; i < countDiary; i += 50) {
    final diaries = isar.diarys.where().findAll(offset: i, limit: 50);
    isar.write((isar) {
      isar.diarys.putAll(diaries);
    });
  }
  isar.close();
}

/// 2.6.0 升级：
/// 新增 `type`（区分纯文本/富文本）与 `lastModified`；旧 `time` 字段同步为最后修改时间。
void _mergeToV2_6_0(String dir) {
  final isar = Isar.open(schemas: _schemas, directory: dir);
  final countDiary = isar.diarys.where().count();

  for (var i = 0; i < countDiary; i += 50) {
    final diaries = isar.diarys.where().findAll(offset: i, limit: 50);

    isar.write((isar) {
      final quillController = QuillController.basic();

      for (final diary in diaries) {
        final type = DiaryType.richText.value;
        final lastModified = diary.time;
        quillController.document = Document.fromJson(
          jsonDecode(diary.content),
        );

        // 原媒体重建依赖已删除的 quill_embed；此迁移仅对极老版本生效，跳过重建。
        // ignore: unused_local_variable
        final _ = [diary.imageName, diary.videoName, diary.audioName];

        final content = jsonEncode(
          quillController.document.toDelta().toJson(),
        );

        isar.diarys.put(
          diary.copyWith(
            content: content,
            type: type,
            lastModified: lastModified,
            time: lastModified,
          ),
        );

        quillController.clear();
      }
    });
  }

  isar.close();
}

/// 2.6.3 修复：遍历日记，缺失的分类自动建一条占位。
void _fixV2_6_3(String dir) {
  final isar = Isar.open(schemas: _schemas, directory: dir);
  final countDiary = isar.diarys.where().count();
  for (var i = 0; i < countDiary; i += 50) {
    final diaries = isar.diarys.where().findAll(offset: i, limit: 50);
    isar.write((isar) {
      for (final diary in diaries) {
        final id = diary.categoryId;
        if (id != null && isar.categorys.where().idEqualTo(id).isEmpty()) {
          isar.categorys.put(
            Category(
              id: id,
              // 只要 4 个随机 hex 字符做名字后缀；本函数在 compute isolate 内运行，
              // RustLib 未初始化，不能走 Rust 侧 uuid。
              categoryName:
                  '已修复${Random().nextInt(0x10000).toRadixString(16).padLeft(4, '0')}',
              lastModified: diary.lastModified,
              parentId: null,
              deleted: false,
            ),
          );
        }
      }
    });
  }
  isar.close();
}

/// 2.7.3 升级：把字体改为存 Isar，KV 内只保留当前选中。
Future<void> _mergeToV2_7_3(Map<String, dynamic> parma) async {
  final isar = Isar.open(schemas: _schemas, directory: parma['database']!);

  await isar.writeAsync((isar) {
    isar.fonts.clear();
    isar.fonts.putAll(parma['fonts']);
  });
}

/// 2.8.0 升级：旧 `type == 'text'`（实为 Quill Delta）并入富文本，仅翻 type，
/// 解析失败再兜底包装；显式回填新增字段默认值（category `deleted=false`）
/// ——默认值由本迁移拥有，model 不再带 defaultValue。
/// 不更新 lastModified，避免误触发同步层的"用户编辑"判断。
void _mergeToV2_8_0(String dir) {
  const legacyTextType = 'text';
  final isar = Isar.open(schemas: _schemas, directory: dir);

  final countDiary = isar.diarys.where().count();
  for (var i = 0; i < countDiary; i += 50) {
    final diaries = isar.diarys.where().findAll(offset: i, limit: 50);

    isar.write((isar) {
      for (final diary in diaries) {
        var content = diary.content;
        var type = diary.type;
        if (type == legacyTextType) {
          try {
            Document.fromJson(jsonDecode(content) as List<dynamic>);
          } catch (_) {
            final doc = Document();
            if (content.isNotEmpty) doc.insert(0, content);
            content = jsonEncode(doc.toDelta().toJson());
          }
          type = DiaryType.richText.value;
        }

        isar.diarys.put(
          diary.copyWith(content: content, type: type),
        );
      }
    });
  }

  final countCategory = isar.categorys.where().count();
  for (var i = 0; i < countCategory; i += 50) {
    final categories = isar.categorys.where().findAll(offset: i, limit: 50);

    isar.write((isar) {
      for (final category in categories) {
        isar.categorys.put(category.copyWith(deleted: false));
      }
    });
  }

  isar.close();
}
