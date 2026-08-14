import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' hide Category;
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:pub_semver/pub_semver.dart';

final _schemas = [DiarySchema, CategorySchema, FontSchema];

class VersionMigrator {
  /// 版本号比对触发数据迁移钩子并写回当前版本号。须在 KV / Isar 初始化后由组合根
  /// （`main.dart`）调用——此前内联在 KV 实现的 `init`，现上移以解除 core → merge
  /// 反向依赖。
  ///
  /// 唯一挂不进这里的迁移是 2.8.0 的 SharedPreferences → MMKV 搬迁：判版本用的
  /// `appVersion` 自己就存在 KV 里，搬完之前读不到，所以它留在 `MmkvKVStorage.init`。
  static Future<void> run() async {
    // prefs→MMKV 搬迁本次被跳过（旧仓库暂时打不开）：appVersion 此刻必为 null，
    // 往下走会把老用户误判成全新安装（searchIndexBackfilled 置 true 后旧仓库里
    // 没有这个键、永远改不回来）。本次什么都不写，下次启动搬迁成功后再判。
    if (MmkvKVStorage.legacyMigrationPending) return;
    final packageInfo = await AppInfo.getPackageInfo();
    final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final appVersion = MoodiaryKVs.appVersion.get();
    if (appVersion != null) {
      await merge(lastAppVersion: appVersion);
    }
    // 全文 / 双链倒排索引首次引入于 2.8.0：全新安装（appVersion==null）的新日记走增量索引，
    // 直接置「已回填」，免搜索页的升级提示；从旧版升级则保持 false，由提示引导用户手动重建一次。
    if (appVersion == null) {
      MoodiaryKVs.searchIndexBackfilled.set(true);
    }
    if (kDebugMode || appVersion == null || appVersion != currentVersion) {
      MoodiaryKVs.appVersion.set(currentVersion);
    }
  }

  /// [lastAppVersion]（形如 `2.7.3+73`，可能带 `-beta` 等 pre-release）是否低于闸门
  /// [gate]。语义化比较：`2.10.0 > 2.9.0` 按字典序会判错，必须走 semver；build 元数据
  /// semver 本就忽略；pre-release 则显式剥掉——beta 渠道的 versionName 带 `-beta`
  /// 后缀，semver 里 `2.8.0-beta < 2.8.0` 恒真，不剥会让迁移每次冷启动重跑一遍。
  @visibleForTesting
  static bool versionBelow(String lastAppVersion, String gate) {
    final parsed = Version.parse(lastAppVersion);
    final normalized = Version(parsed.major, parsed.minor, parsed.patch);
    return normalized < Version.parse(gate);
  }

  static Future<void> merge({required String lastAppVersion}) async {
    bool below(String version) => versionBelow(lastAppVersion, version);

    if (below('2.4.8')) {
      await compute(_mergeToV2_4_8, AppFiles.getRealPath('database', ''));
    }

    if (below('2.6.0')) {
      await compute(_mergeToV2_6_0, AppFiles.getRealPath('database', ''));
    }

    if (below('2.6.2')) {
      await MediaManager.regenerateMissingThumbnails();
    }

    if (below('2.6.3')) {
      await AppFiles.cleanFile(AppFiles.getRealPath('database', ''));
      await MediaManager.regenerateMissingThumbnails();
      await compute(_fixV2_6_3, AppFiles.getRealPath('database', ''));
    }

    if (below('2.7.3')) {
      MoodiaryKVs.customFont.set('');
      final allFont = await FontManager.getAllFonts();
      await compute(_mergeToV2_7_3, {
        'database': AppFiles.getRealPath('database', ''),
        'fonts': allFont,
      });
    }

    if (below('2.8.0')) {
      // 2.7.3 的 autoSync 属旧备份引擎；新引擎启动后 ~30s 即全量推送、且未配 DEK 时为明文，
      // 不能默认继承——重置为关。同步引擎已整体重写，旧 WebDAV 配置（prefs 里的
      // webDavOption）**有意不迁移**，由用户在同步页重新配置；旧仓库里那份由
      // 「重置全部数据」的 clearStore 负责清。
      // 旧主题强调色（prefs 的 color/colorType）同样**有意不映射**：配色已重做为
      // 灰度/壁纸/自定义三态，升级后回落默认灰度，由用户重新选择。
      MoodiaryKVs.autoSync.set(false);
      // 跨引擎（isar 4.0.0-dev → isar_plus）迁移前留一份快照，出问题可回滚。
      await _backupDatabaseOnce();
      await compute(_mergeToV2_8_0, AppFiles.getRealPath('database', ''));
    }
  }

  /// 测试直通：宿主测试的 `ISAR_TEST_DYLIB` 库路径只在主 isolate 注册过，
  /// compute 子 isolate 解析不到原生库，集成测试改在主 isolate 直接驱动本步骤。
  @visibleForTesting
  static void debugMergeToV280(String dir) => _mergeToV2_8_0(dir);
}

/// 2.8.0 迁移前对数据库文件做一次性快照备份（`default.isar.v273bak`）：跨引擎迁移 / 写回
/// 若出问题可回滚。已存在备份或库文件缺失则跳过；备份失败仅跳过、不阻断迁移。
Future<void> _backupDatabaseOnce() async {
  try {
    final src = File(AppFiles.getRealPath('database', 'default.isar'));
    final dst = AppFiles.getRealPath('database', 'default.isar.v273bak');
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
      for (final diary in diaries) {
        final lastModified = diary.time;
        // 内容本就是 Delta，原先经 QuillController 空转一次等价于原样保留；
        // 不是合法 Delta 的（极老版本的裸文本）包成最小 Delta，避免后续读取失败。
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
/// 解析失败再兜底包装。不更新 lastModified，避免误触发同步层的"用户编辑"判断。
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
          if (!QuillDelta.isDelta(content)) {
            content = QuillDelta.wrapPlainText(content);
          }
          type = DiaryType.richText.value;
        }

        isar.diarys.put(diary.copyWith(content: content, type: type));
      }
    });
  }

  isar.close();
}
