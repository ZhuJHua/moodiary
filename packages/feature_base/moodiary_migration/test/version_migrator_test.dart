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

  // 顶层初始化（不放在任一 group 里）：setUpAll 只在本 group 有用例被选中时才跑，
  // 挂在 2.8.0 组会让单跑旧步骤组（--plain-name '2.6.0'）拿到 IsarNotReadyError。
  setUpAll(() async {
    await Isar.initialize(dylib);
  });

  group('2.8.0 迁移步骤（真库）', () {
    late Directory dir;
    late Isar isar;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('moodiary_migration_test');
      // 与 _mergeToV2_8_0 内部的开库列表同源（legacyMigrationSchemas 是真源前缀）。
      isar = .open(
        schemas: legacyMigrationSchemas,
        directory: dir.path,
        inspector: false,
      );
    });

    tearDown(() {
      if (isar.isOpen) isar.close();
      dir.deleteSync(recursive: true);
    });

    void seed(List<Diary> diaries) {
      isar.write((isar) => isar.diarys.putAll(diaries));
    }

    // 生产路径在 compute 子 isolate 里 open + close 同目录库；测试进程内同目录
    // open 返回同一实例，merge 末尾的 close 会把测试自己的句柄一并关掉——
    // 每次跑完重开一份再断言。
    void runMerge() {
      VersionMigrator.debugMergeToV280(dir.path);
      isar = .open(
        schemas: legacyMigrationSchemas,
        directory: dir.path,
        inspector: false,
      );
    }

    Diary byId(String id) => isar.diarys.where().idEqualTo(id).findFirst()!;

    test('text 裸文本被包装成 Delta 并翻成 richText，时间戳原样保留', () {
      seed([_legacyDiary('t1', type: 'text', content: '第一篇\n随手记')]);
      runMerge();

      final d = byId('t1');
      expect(d.type, DiaryType.richText.value);
      expect(QuillDelta.isDelta(d.content), isTrue);
      expect(QuillDelta.plainText(d.content), '第一篇\n随手记\n');
      // isar_plus 反序列化会 toLocal（时刻守恒、isUtc 翻转），按绝对时刻比较。
      expect(d.lastModified.toUtc(), DateTime.utc(2024, 6, 2));
      expect(d.time.toUtc(), DateTime.utc(2024, 6, 1));
    });

    test('恰好是 JSON 数组的裸文本同样被包装——不得漏成"合法 Delta"静默清空', () {
      const raw = '["买菜","做饭"]';
      seed([_legacyDiary('t2', type: 'text', content: raw)]);
      runMerge();

      final d = byId('t2');
      expect(d.type, DiaryType.richText.value);
      final ops = jsonDecode(d.content) as List;
      expect(ops, hasLength(1));
      expect((ops.single as Map)['insert'], '$raw\n');
    });

    test('text 里已是合法 Delta 的只翻 type，内容逐字节不动', () {
      const delta = '[{"insert":"正文\\n"}]';
      seed([_legacyDiary('t3', type: 'text', content: delta)]);
      runMerge();

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
      runMerge();

      expect(byId('r1').content, delta);
      expect(byId('r1').type, 'richText');
      expect(byId('m1').content, md);
      expect(byId('m1').type, 'markdown');
    });

    test('幂等：重复执行结果不变', () {
      seed([_legacyDiary('t4', type: 'text', content: '重复跑')]);
      runMerge();
      final first = byId('t4').content;
      runMerge();
      expect(byId('t4').content, first);
      expect(byId('t4').type, DiaryType.richText.value);
    });
  });

  group('2.6.0 / 2.6.3 / 2.7.3 旧步骤（真库）', () {
    late Directory dir;
    late Isar isar;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('moodiary_legacy_mig_test');
      isar = .open(
        schemas: legacyMigrationSchemas,
        directory: dir.path,
        inspector: false,
      );
    });

    tearDown(() {
      if (isar.isOpen) isar.close();
      dir.deleteSync(recursive: true);
    });

    // 旧步骤在同 isolate 内 open + close 同目录库，跑完重开句柄（同 2.8.0 组）。
    void reopen() {
      isar = .open(
        schemas: legacyMigrationSchemas,
        directory: dir.path,
        inspector: false,
      );
    }

    Diary byId(String id) => isar.diarys.where().idEqualTo(id).findFirst()!;

    test('2.6.0：裸文本包成 Delta、翻 richText、lastModified 对齐 time；重跑幂等', () {
      const delta = '[{"insert":"已是 Delta\\n"}]';
      isar.write(
        (i) => i.diarys.putAll([
          _legacyDiary('plain', type: 'text', content: '第一篇\n随手记'),
          _legacyDiary('delta', type: 'text', content: delta),
        ]),
      );
      VersionMigrator.debugMergeToV260(dir.path);
      reopen();

      final plain = byId('plain');
      expect(QuillDelta.isDelta(plain.content), isTrue, reason: '裸文本被包装');
      expect(QuillDelta.plainText(plain.content), '第一篇\n随手记\n');
      expect(plain.type, DiaryType.richText.value);
      // lastModified 同步为 time（该版本新增字段的回填语义）。
      expect(plain.lastModified.toUtc(), plain.time.toUtc());
      expect(byId('delta').content, delta, reason: '合法 Delta 逐字节不动');

      final first = (plain: plain.content, delta: byId('delta').content);
      VersionMigrator.debugMergeToV260(dir.path);
      reopen();
      expect(byId('plain').content, first.plain, reason: '重跑幂等');
      expect(byId('delta').content, first.delta);
    });

    test('2.6.3：悬挂 categoryId 补占位分类；已存在的不重复建', () {
      isar.write((i) {
        i.categorys.put(
          Category(id: 'ok', categoryName: '在册', lastModified: DateTime(2024)),
        );
        i.diarys.putAll([
          _legacyDiary(
            'a',
            type: 'richText',
            content: '[{"insert":"x\\n"}]',
          ).copyWith(categoryId: 'dangling'),
          _legacyDiary(
            'b',
            type: 'richText',
            content: '[{"insert":"y\\n"}]',
          ).copyWith(categoryId: 'ok'),
        ]);
      });
      VersionMigrator.debugFixV263(dir.path);
      reopen();

      expect(isar.categorys.where().idEqualTo('dangling').findFirst(), isNotNull);
      expect(isar.categorys.where().count(), 2, reason: '在册的不重复建');
    });

    test('2.7.3：字体表清空重灌；重跑幂等', () async {
      isar.write(
        (i) => i.fonts.put(
          const Font(fontFileName: 'stale.ttf', fontWghtAxisMap: {}),
        ),
      );
      const scanned = [
        Font(fontFileName: 'a.ttf', fontWghtAxisMap: {'wght': 400}),
        Font(fontFileName: 'b.otf', fontWghtAxisMap: {}),
      ];
      await VersionMigrator.debugMergeToV273(dir.path, scanned);
      reopen();

      expect(isar.fonts.where().count(), 2, reason: '旧行被清空、重灌磁盘扫描结果');
      expect(
        isar.fonts.where().findAll().map((f) => f.fontFileName).toSet(),
        {'a.ttf', 'b.otf'},
      );

      await VersionMigrator.debugMergeToV273(dir.path, scanned);
      reopen();
      expect(isar.fonts.where().count(), 2, reason: '重跑幂等');
    });
  });
}
