import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fast_tokenizer/fast_tokenizer.dart' show TokenizeResult;
import 'package:fast_tokenizer/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_export/moodiary_export.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:path/path.dart' as p;

Future<TokenizeResult> _fakeTokenize(String text) async {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return TokenizeResult(cut: words, cutForSearch: words);
}

class _FakeStore implements ImportMediaStore {
  var _n = 0;

  @override
  Future<String?> save(String path, ImportMediaKind kind) async {
    _n++;
    return switch (kind) {
      .image => 'image-$_n.jpg',
      .video => 'video-$_n.mp4',
      .audio => 'audio-$_n.m4a',
    };
  }
}

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository diaries;
  late CategoryRepository categories;
  late PlaceRepository places;
  late Directory root;
  late MarkdownImporter importer;

  setUpAll(() {
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
  });

  setUp(() {
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    installFakeFastTokenizer(_fakeTokenize);
    diaries = DiaryRepository(db);
    categories = CategoryRepository(db);
    places = PlaceRepository(db);
    root = Directory.systemTemp.createTempSync('md-importer');
    importer = MarkdownImporter(
      diaries: diaries,
      categories: categories,
      places: places,
      media: _FakeStore(),
      now: () => DateTime.utc(2026, 9, 6, 12),
    );
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void write(String name, String content) =>
      File(p.join(root.path, name)).writeAsStringSync(content);

  MarkdownImportSource source() => MarkdownImportSource.scan(root);

  test('front matter 全量落库，分类复用一次、地点按名新建', () async {
    const head = '''
---
time: "2026-09-01T08:00:00.000Z"
mood: travel
category: "旅行"
weather: ["100", "26", "晴"]
position: ["30.25", "120.15", "西湖"]
tags: ["a"]
---
''';
    write('2026-09-01-一.md', '$head\n# 第一天\n\n出发');
    write('2026-09-02-二.md', '$head\n到达');
    // 导出形态：front matter 有 title，正文又以同名一级标题开头 —— 那行不该进正文。
    write('2026-09-03-三.md', '---\ntitle: "第三天"\n---\n\n# 第三天\n\n# 小标题\n\n到家');

    final report = await importer.run(source());
    expect(report.diaries, 3);
    expect(report.categories, 1);
    expect(report.places, 1);
    expect(report.failed, 0);
    expect(report.cancelled, isFalse);

    final all = await diaries.getAllDiaries();
    expect(all, hasLength(3));
    final third = all.singleWhere((d) => d.title == '第三天');
    expect(third.contentText, '小标题\n到家');
    final first = all.singleWhere((d) => d.title == '第一天');
    expect(first.time, DateTime.utc(2026, 9, 1, 8));
    expect(first.mood, DiaryMood.travel);
    expect(first.weather?.temp, '26');
    expect(first.tags, ['a']);
    expect(first.type, DiaryType.tiptap.value);
    expect(first.contentText, '出发');
    expect(first.lastModified, DateTime.utc(2026, 9, 6, 12));

    final category = (await categories.getAllCategories()).single;
    expect(category.categoryName, '旅行');
    final withHead = all.where((d) => d.title != '第三天');
    expect(withHead.every((d) => d.categoryId == category.id), isTrue);

    final place = (await places.getAllPlaces()).single;
    expect(place.id, Place.idForName('西湖'));
    expect(withHead.every((d) => d.placeId == place.id), isTrue);

    // 第二篇没有一级标题：标题来自文件名。
    expect(all.singleWhere((d) => d.title == '二').contentText, '到达');
  });

  test('已存在的 id 与本批重复的 id 跳过，缺时间用文件名日期', () async {
    const id = '01912345-89ab-7cde-8f01-23456789abcd';
    await diaries.insertADiary(
      Diary.empty(type: .tiptap).copyWith(id: id, title: '旧'),
    );
    write('2026-09-03-a.md', '---\nid: "$id"\n---\n新');
    write('2026-09-04-b.md', '---\nid: "$id"\n---\n新');
    write('2026-09-05-c.md', '正文');

    final report = await importer.run(source());
    expect(report.skipped, 2);
    expect(report.diaries, 1);
    final imported = (await diaries.getAllDiaries()).singleWhere(
      (d) => d.title == 'c',
    );
    expect(imported.time, DateTime(2026, 9, 5).toUtc());
    expect((await diaries.getDiaryByBusinessId(id))!.title, '旧');
  });

  test('媒体改写后三列由正文派生', () async {
    Directory(p.join(root.path, 'assets')).createSync();
    File(p.join(root.path, 'assets', 'p.jpg')).writeAsBytesSync([0]);
    File(p.join(root.path, 'assets', 'v.mp4')).writeAsBytesSync([0]);
    write(
      'm.md',
      '![图](assets/p.jpg)\n\n[视频](assets/v.mp4)\n\n![丢了](assets/gone.jpg)',
    );

    final report = await importer.run(source());
    expect(report.diaries, 1);
    expect(report.missingMedia, 1);
    final diary = (await diaries.getAllDiaries()).single;
    expect(diary.imageName, ['image-1.jpg']);
    expect(diary.videoName, ['video-2.mp4']);
    final doc = jsonDecode(diary.content) as Map<String, dynamic>;
    final types = [for (final n in doc['content'] as List) n['type']];
    expect(types, contains('image'));
    expect(types, contains('video'));
  });

  test('单篇失败不中止，取消后已转换的落库', () async {
    write('1.md', '一');
    write('2.md', '二');
    write('3.md', '三');
    final entries = source();
    // 扫描后删掉第二篇：读取失败计 failed。
    File(entries.entries[1].path).deleteSync();

    final report = await importer.run(entries);
    expect(report.failed, 1);
    expect(report.diaries, 2);

    var seen = 0;
    final cancelled = await importer.run(
      MarkdownImportSource.scan(root),
      isCancelled: () => seen++ >= 1,
    );
    expect(cancelled.cancelled, isTrue);
    expect(cancelled.diaries, 1);
  });
}
