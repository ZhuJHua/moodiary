// 版本迁移链测试，分两层：
//
// 1. 闸门语义（无门控，CI 常跑）：versionBelow 的 semver 比较——2.8.0 发版前
//    版本号闸门恒真的事故正是这一层没有测试才漏的。
// 2. 2.8.0 迁移步骤（真库集成，需 `ISAR_TEST_DYLIB` 指向 libisar_plus 动态库，
//    获取方式见 moodiary_data/test/diary_index_test.dart 文件头）：对 2.7.3 时代
//    的行形状验证 type=='text' 的翻转与包装。isar_plus 与旧引擎按名匹配字段、
//    磁盘格式兼容，「旧数据」的本质是旧行形状而非旧二进制。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

Diary _legacyDiary(
  String id, {
  required String type,
  required String content,
}) => Diary(
  id: id,
  title: '',
  content: content,
  contentText: '',
  time: DateTime.utc(2024, 6, 1),
  lastModified: DateTime.utc(2024, 6, 2),
  show: true,
  mood: 0.5,
  weather: const [],
  imageName: const [],
  audioName: const [],
  videoName: const [],
  tags: const [],
  position: const [],
  type: type,
);

void main() {
  group('versionBelow 闸门语义', () {
    test('低版本在闸门之下', () {
      expect(VersionMigrator.versionBelow('2.7.3+73', '2.8.0'), isTrue);
      expect(VersionMigrator.versionBelow('2.4.7+50', '2.4.8'), isTrue);
    });

    test('同版本与更高版本不触发（含 build 元数据）', () {
      expect(VersionMigrator.versionBelow('2.8.0+94', '2.8.0'), isFalse);
      expect(VersionMigrator.versionBelow('2.8.1+1', '2.8.0'), isFalse);
      expect(VersionMigrator.versionBelow('2.8.0+999', '2.8.0'), isFalse);
    });

    test('pre-release 被剥掉：beta 渠道不得每次冷启动重跑迁移', () {
      expect(VersionMigrator.versionBelow('2.8.0-beta+94', '2.8.0'), isFalse);
      expect(VersionMigrator.versionBelow('2.7.3-beta+73', '2.8.0'), isTrue);
    });

    test('semver 比较而非字典序', () {
      expect(VersionMigrator.versionBelow('2.10.0+1', '2.9.0'), isFalse);
      expect(VersionMigrator.versionBelow('2.9.0+1', '2.10.0'), isTrue);
    });
  });

  group('merge 在 2.8.0 及以上是纯 no-op', () {
    // 全部 below() 为假时 merge 不得触碰 KV / Isar / 文件——这些单例在本测试里
    // 均未注册，触碰即抛。
    test('正式版与 beta 版都直接返回', () async {
      await VersionMigrator.merge(lastAppVersion: '2.8.0+94');
      await VersionMigrator.merge(lastAppVersion: '2.8.0-beta+94');
      await VersionMigrator.merge(lastAppVersion: '2.9.1+120');
    });
  });

  final dylib = Platform.environment['ISAR_TEST_DYLIB'];
  if (dylib == null || dylib.isEmpty) {
    test(
      '2.8.0 迁移步骤（skipped）',
      () {},
      skip: '需要 ISAR_TEST_DYLIB 指向 libisar_plus 动态库，见文件头注释',
    );
    return;
  }

  group('2.8.0 迁移步骤（真库）', () {
    late Directory dir;
    late Isar isar;

    setUpAll(() async {
      await Isar.initialize(dylib);
    });

    setUp(() {
      dir = Directory.systemTemp.createTempSync('moodiary_migration_test');
      // 与 _mergeToV2_8_0 内部的开库列表一致（同列表 = 无子集前缀问题）。
      isar = .open(
        schemas: [DiarySchema, CategorySchema, FontSchema],
        directory: dir.path,
        inspector: false,
      );
    });

    tearDown(() {
      isar.close();
      dir.deleteSync(recursive: true);
    });

    void seed(List<Diary> diaries) {
      isar.write((isar) => isar.diarys.putAll(diaries));
    }

    Diary byId(String id) => isar.diarys.where().idEqualTo(id).findFirst()!;

    test('text 裸文本被包装成 Delta 并翻成 richText，时间戳原样保留', () {
      seed([_legacyDiary('t1', type: 'text', content: '第一篇\n随手记')]);
      VersionMigrator.debugMergeToV280(dir.path);

      final d = byId('t1');
      expect(d.type, DiaryType.richText.value);
      expect(QuillDelta.isDelta(d.content), isTrue);
      expect(QuillDelta.plainText(d.content), '第一篇\n随手记\n');
      expect(d.lastModified, DateTime.utc(2024, 6, 2));
      expect(d.time, DateTime.utc(2024, 6, 1));
    });

    test('恰好是 JSON 数组的裸文本同样被包装——不得漏成"合法 Delta"静默清空', () {
      const raw = '["买菜","做饭"]';
      seed([_legacyDiary('t2', type: 'text', content: raw)]);
      VersionMigrator.debugMergeToV280(dir.path);

      final d = byId('t2');
      expect(d.type, DiaryType.richText.value);
      final ops = jsonDecode(d.content) as List;
      expect(ops, hasLength(1));
      expect((ops.single as Map)['insert'], '$raw\n');
    });

    test('text 里已是合法 Delta 的只翻 type，内容逐字节不动', () {
      const delta = '[{"insert":"正文\\n"}]';
      seed([_legacyDiary('t3', type: 'text', content: delta)]);
      VersionMigrator.debugMergeToV280(dir.path);

      final d = byId('t3');
      expect(d.type, DiaryType.richText.value);
      expect(d.content, delta);
    });

    test('richText 与 markdown 行原样不动', () {
      const delta = '[{"insert":"已是富文本\\n"}]';
      const md = '# 标题\n正文';
      seed([
        _legacyDiary('r1', type: 'richText', content: delta),
        _legacyDiary('m1', type: 'markdown', content: md),
      ]);
      VersionMigrator.debugMergeToV280(dir.path);

      expect(byId('r1').content, delta);
      expect(byId('r1').type, 'richText');
      expect(byId('m1').content, md);
      expect(byId('m1').type, 'markdown');
    });

    test('幂等：重复执行结果不变', () {
      seed([_legacyDiary('t4', type: 'text', content: '重复跑')]);
      VersionMigrator.debugMergeToV280(dir.path);
      final first = byId('t4').content;
      VersionMigrator.debugMergeToV280(dir.path);
      expect(byId('t4').content, first);
      expect(byId('t4').type, DiaryType.richText.value);
    });
  });
}
