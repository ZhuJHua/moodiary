// SQLite（drift 内存库）上的仓储集成测试：FTS5 检索、双链/图谱、子表装配、
// 事件与墓碑语义。无原生 dylib 门槛——sqlite3 的 code asset 由 flutter test
// 自动构建（P0 已验证），分词走替身（moodiary_rust/testing.dart）。
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/foundation.dart' show TokenizeResult;
import 'package:moodiary_rust/testing.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

/// 替身分词：空白切词（保留重复，词频 = 出现次数），cut 与 cutForSearch 同词表。
Future<TokenizeResult> fakeTokenize(String text) async {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return TokenizeResult(cut: words, cutForSearch: words);
}

Diary makeDiary(
  String id,
  String text, {
  String? content,
  String? title,
  List<String> linkTo = const [],
  List<String> images = const [],
  List<String> audios = const [],
  List<String> videos = const [],
  List<String> tags = const [],
  DateTime? time,
  String? categoryId,
  bool show = true,
}) {
  final doc =
      content ??
      jsonEncode({
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': text},
              for (final target in linkTo)
                {
                  'type': 'diaryLink',
                  'attrs': {'id': target},
                },
              for (final name in [...images, ...videos, ...audios])
                {
                  'type': name.startsWith('image')
                      ? 'image'
                      : name.startsWith('video')
                      ? 'video'
                      : 'audio',
                  'attrs': {'filename': name},
                },
            ],
          },
        ],
      });
  return Diary(
    id: id,
    categoryId: categoryId,
    title: title ?? 'title-$id',
    content: doc,
    contentText: text,
    time: time ?? DateTime.utc(2026, 1, 1),
    lastModified: time ?? DateTime.utc(2026, 1, 1),
    show: show,
    mood: 0.5,
    imageName: images,
    audioName: audios,
    videoName: videos,
    tags: tags,
    type: 'tiptap',
  );
}

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository repo;

  setUpAll(() {
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
  });

  setUp(() async {
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    installFakeRustLib(fakeTokenize);
    repo = .forTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<Diary>> search(String word) =>
      repo.searchDiaries(cutTokens: [word], cutForSearchTokens: const []);

  group('检索', () {
    test('插入后可按分词搜索到', () async {
      await repo.insertADiary(makeDiary('d1', '苹果 香蕉'));
      expect((await search('苹果')).map((d) => d.id), ['d1']);
      expect(await search('梨子'), isEmpty);
    });

    test('OR 召回：任一词命中即入选', () async {
      await repo.insertDiaries([
        makeDiary('d1', '苹果'),
        makeDiary('d2', '香蕉'),
        makeDiary('d3', '梨子'),
      ]);
      final hits = await repo.searchDiaries(
        cutTokens: const ['苹果', '香蕉'],
        cutForSearchTokens: const [],
      );
      expect(hits.map((d) => d.id).toSet(), {'d1', 'd2'});
    });

    test('词频参与排序：重复越多越靠前', () async {
      await repo.insertDiaries([
        makeDiary('once', '苹果 别的 词 拉长 正文 篇幅 大致 相当'),
        makeDiary('thrice', '苹果 苹果 苹果 别的 词 拉长 正文 篇幅'),
      ]);
      expect((await search('苹果')).first.id, 'thrice');
    });

    test('标题命中权重高于正文命中', () async {
      await repo.insertDiaries([
        makeDiary('body', '苹果 正文 提到', title: '无关'),
        makeDiary('title', '完全 无关 的 正文', title: '苹果'),
      ]);
      expect((await search('苹果')).first.id, 'title');
    });

    test('分类与时间窗过滤下推', () async {
      await repo.insertDiaries([
        makeDiary('a', '苹果', categoryId: 'c1', time: DateTime.utc(2026, 1, 1)),
        makeDiary('b', '苹果', categoryId: 'c2', time: DateTime.utc(2026, 2, 1)),
        makeDiary('c', '苹果', categoryId: 'c1', time: DateTime.utc(2026, 3, 1)),
      ]);
      final byCat = await repo.searchDiaries(
        cutTokens: const ['苹果'],
        cutForSearchTokens: const [],
        categoryId: 'c1',
      );
      expect(byCat.map((d) => d.id).toSet(), {'a', 'c'});
      final byTime = await repo.searchDiaries(
        cutTokens: const ['苹果'],
        cutForSearchTokens: const [],
        start: DateTime.utc(2026, 1, 15),
        end: DateTime.utc(2026, 2, 15),
      );
      expect(byTime.map((d) => d.id), ['b']);
    });

    test('timeDesc/timeAsc 排序忽略相关性', () async {
      await repo.insertDiaries([
        makeDiary('old', '苹果 苹果 苹果', time: DateTime.utc(2026, 1, 1)),
        makeDiary('new', '苹果', time: DateTime.utc(2026, 5, 1)),
      ]);
      final desc = await repo.searchDiaries(
        cutTokens: const ['苹果'],
        cutForSearchTokens: const [],
        sort: .timeDesc,
      );
      expect(desc.map((d) => d.id), ['new', 'old']);
      final asc = await repo.searchDiaries(
        cutTokens: const ['苹果'],
        cutForSearchTokens: const [],
        sort: .timeAsc,
      );
      expect(asc.map((d) => d.id), ['old', 'new']);
    });

    test('searchDiariesByText 走同一分词并截断', () async {
      await repo.insertDiaries([
        for (var i = 0; i < 5; i++) makeDiary('d$i', '苹果 编号 $i'),
      ]);
      final hits = await repo.searchDiariesByText('苹果', limit: 3);
      expect(hits, hasLength(3));
    });

    test('更新替换索引：旧词摘除、新词可搜', () async {
      final d = makeDiary('d1', '苹果');
      await repo.insertADiary(d);
      await repo.updateADiary(
        newDiary: d.copyWith(contentText: '香蕉', content: '香蕉'),
      );
      expect(await search('苹果'), isEmpty);
      expect((await search('香蕉')).map((e) => e.id), ['d1']);
    });

    test('skip 模式不动索引（软删走查询期过滤）', () async {
      final d = makeDiary('d1', '苹果');
      await repo.insertADiary(d);
      await repo.setVisibility(d, show: false);
      expect(await search('苹果'), isEmpty, reason: '回收站不进搜索结果');
      final restored = (await repo.getRecycleBinDiaries()).single;
      await repo.setVisibility(restored, show: true);
      expect((await search('苹果')).map((e) => e.id), ['d1']);
    });

    test('同 id 重复插入不产生重复行/重复命中', () async {
      final d = makeDiary('d1', '苹果');
      await repo.insertADiary(d);
      await repo.insertADiary(d);
      expect(await repo.getAllDiaries(), hasLength(1));
      expect(await search('苹果'), hasLength(1));
    });
  });

  group('子表装配', () {
    test('媒体三列与标签保序往返', () async {
      final d = makeDiary(
        'd1',
        '正文',
        images: ['image-b.jpg', 'image-a.jpg'],
        audios: ['audio-1.m4a'],
        videos: ['video-1.mp4'],
        tags: ['旅行', '随笔'],
      );
      await repo.insertADiary(d);
      final got = (await repo.getDiaryByBusinessId('d1'))!;
      expect(got.imageName, ['image-b.jpg', 'image-a.jpg']);
      expect(got.audioName, ['audio-1.m4a']);
      expect(got.videoName, ['video-1.mp4']);
      expect(got.tags, ['旅行', '随笔']);
    });

    test('position/weather 值对象往返（含 null）', () async {
      final withMeta = makeDiary('d1', '正文').copyWith(
        position: const DiaryPosition(
          latitude: 24.48,
          longitude: 118.08,
          name: '厦门 环岛路',
        ),
        weather: const DiaryWeather(icon: '100', temp: '26', text: '晴'),
      );
      await repo.insertADiary(withMeta);
      await repo.insertADiary(makeDiary('d2', '正文'));
      final a = (await repo.getDiaryByBusinessId('d1'))!;
      expect(a.position?.name, '厦门 环岛路');
      expect(a.position?.latitude, 24.48);
      expect(a.weather?.text, '晴');
      final b = (await repo.getDiaryByBusinessId('d2'))!;
      expect(b.position, isNull);
      expect(b.weather, isNull);
    });

    test('getMediaSourceDiaries 按类型过滤且排序稳定', () async {
      await repo.insertDiaries([
        makeDiary(
          'img',
          '正文',
          images: ['image-1.jpg'],
          time: DateTime.utc(2026, 1, 2),
        ),
        makeDiary(
          'aud',
          '正文',
          audios: ['audio-1.m4a'],
          time: DateTime.utc(2026, 1, 3),
        ),
        makeDiary('none', '正文', time: DateTime.utc(2026, 1, 4)),
        makeDiary(
          'img2',
          '正文',
          images: ['image-2.jpg'],
          time: DateTime.utc(2026, 1, 5),
        ),
      ]);
      final imgs = await repo.getMediaSourceDiaries(type: .image);
      expect(imgs.map((d) => d.id), ['img2', 'img']);
      final auds = await repo.getMediaSourceDiaries(type: .audio);
      expect(auds.map((d) => d.id), ['aud']);
    });

    test('collectReferencedMedia 汇总含回收站', () async {
      await repo.insertDiaries([
        makeDiary('a', '正文', images: ['image-1.jpg']),
        makeDiary('b', '正文', audios: ['audio-1.m4a'], show: false),
      ]);
      final refs = await repo.collectReferencedMedia();
      expect(refs.images, {'image-1.jpg'});
      expect(refs.audios, {'audio-1.m4a'});
    });
  });

  group('删除与墓碑', () {
    test('永久删除：行硬删 + 墓碑 + 索引摘除', () async {
      await repo.insertADiary(makeDiary('d1', '苹果'));
      expect(await repo.deleteADiary('d1'), isTrue);
      expect(await repo.getDiaryByBusinessId('d1'), isNull);
      expect(await search('苹果'), isEmpty);
      final tombstone = await TombstoneRepository.forTesting(db)
          .getByKey(SyncTombstone.diaryKey('d1'));
      expect(tombstone, isNotNull);
    });

    test('复活闸门：重插同 id 清墓碑', () async {
      await repo.insertADiary(makeDiary('d1', '苹果'));
      await repo.tombstoneDiaryForSync(makeDiary('d1', '苹果'));
      await repo.insertADiary(makeDiary('d1', '苹果'));
      final tombstone = await TombstoneRepository.forTesting(db)
          .getByKey(SyncTombstone.diaryKey('d1'));
      expect(tombstone, isNull);
    });

    test('deleteDiariesByIds 不留墓碑', () async {
      await repo.insertDiaries([makeDiary('a', '一'), makeDiary('b', '二')]);
      await repo.deleteDiariesByIds(['a', 'b']);
      expect(await repo.getAllDiaries(), isEmpty);
      expect(await TombstoneRepository.forTesting(db).getAll(), isEmpty);
    });

    test('事件携带业务 id', () async {
      final events = <DiaryEvent>[];
      final sub = repo.diaryEvents.listen(events.add);
      addTearDown(sub.cancel);
      await repo.insertADiary(makeDiary('d1', '一'));
      await repo.deleteADiary('d1');
      await pumpEventQueue();
      expect(events.whereType<DiaryCreated>().single.diary.id, 'd1');
      expect(events.whereType<DiaryDeleted>().single.id, 'd1');
    });
  });

  group('双链与图谱', () {
    test('正反链 + hasAnyLink + 自链排除', () async {
      await repo.insertDiaries([
        makeDiary('b', '目标'),
        makeDiary('a', '源', linkTo: ['b']),
        makeDiary('selfy', '自链', linkTo: ['selfy']),
      ]);
      expect((await repo.getForwardLinks('a')).map((d) => d.id), ['b']);
      expect((await repo.getBacklinks('b')).map((d) => d.id), ['a']);
      expect(await repo.hasAnyLink('a'), isTrue);
      expect(await repo.hasAnyLink('b'), isTrue);
      expect(await repo.hasAnyLink('selfy'), isFalse);
    });

    test('回收站源不出现在反链', () async {
      await repo.insertDiaries([
        makeDiary('b', '目标'),
        makeDiary('a', '源', linkTo: ['b']),
      ]);
      final a = (await repo.getDiaryByBusinessId('a'))!;
      await repo.setVisibility(a, show: false);
      expect(await repo.getBacklinks('b'), isEmpty);
    });

    test('buildLinkGraph：linked-only，悬空边丢弃，有向边', () async {
      await repo.insertDiaries([
        makeDiary('b', '目标', time: DateTime.utc(2026, 1, 1)),
        makeDiary(
          'a',
          '源',
          linkTo: ['b', 'ghost'],
          time: DateTime.utc(2026, 2, 1),
        ),
        makeDiary('alone', '孤立'),
      ]);
      final graph = await repo.buildLinkGraph();
      expect(graph.nodes.map((n) => n.id).toSet(), {'a', 'b'});
      expect(graph.edges, hasLength(2));
      final src = graph.nodes[graph.edges[0]].id;
      final dst = graph.nodes[graph.edges[1]].id;
      expect((src, dst), ('a', 'b'));
    });

    test('buildEgoGraph：中心恒在下标 0，含孤点中心', () async {
      await repo.insertDiaries([
        makeDiary('center', '中心'),
        makeDiary('n1', '邻居', linkTo: ['center']),
      ]);
      final graph = await repo.buildEgoGraph('center');
      expect(graph.centerIndex, 0);
      expect(graph.nodes.first.id, 'center');
      expect(graph.nodes.map((n) => n.id).toSet(), {'center', 'n1'});

      final lonely = await repo.buildEgoGraph('center', depth: 1);
      expect(lonely.nodes, isNotEmpty);
      await repo.deleteADiary('n1');
      final orphan = await repo.buildEgoGraph('center');
      expect(orphan.nodes.map((n) => n.id), ['center']);
      expect(orphan.edges, isEmpty);
    });

    test('buildEgoGraph：经不可见中间节点的深层孤岛被剪除', () async {
      await repo.insertDiaries([
        makeDiary('center', '中心'),
        makeDiary('mid', '中间', linkTo: ['center']),
        makeDiary('far', '远端', linkTo: ['mid']),
      ]);
      final mid = (await repo.getDiaryByBusinessId('mid'))!;
      await repo.setVisibility(mid, show: false);
      final graph = await repo.buildEgoGraph('center', depth: 2);
      expect(graph.nodes.map((n) => n.id), ['center']);
    });
  });

  group('列表与统计', () {
    test('分页顺序与 diarySortComparator 逐字段一致（同 time 按 id 兜底）', () async {
      final t = DateTime.utc(2026, 1, 1);
      final diaries = [
        makeDiary('0001', '一', time: t),
        makeDiary('0003', '三', time: t),
        makeDiary('0002', '二', time: t),
        makeDiary('0004', '四', time: DateTime.utc(2026, 2, 1)),
      ];
      await repo.insertDiaries(diaries);
      final fromDb = await repo.getDiaryByCategory(sort: .timeDesc);
      final inMemory = [...diaries]..sort(diarySortComparator(.timeDesc));
      expect(fromDb.map((d) => d.id), inMemory.map((d) => d.id));
      // 分页切片与整读前缀一致
      final page1 = await repo.getDiaryByCategory(
        sort: .timeDesc,
        limit: 2,
        offset: 0,
      );
      final page2 = await repo.getDiaryByCategory(
        sort: .timeDesc,
        limit: 2,
        offset: 2,
      );
      expect([...page1, ...page2].map((d) => d.id), fromDb.map((d) => d.id));
    });

    test('未分类过滤与分类计数', () async {
      await repo.insertDiaries([
        makeDiary('a', '一', categoryId: 'c1'),
        makeDiary('b', '二'),
        makeDiary('c', '三', categoryId: 'c1'),
        makeDiary('d', '回收站', categoryId: 'c1', show: false),
      ]);
      final uncat = await repo.getDiaryByCategory(uncategorized: true);
      expect(uncat.map((d) => d.id), ['b']);
      final counts = await repo.diaryCountByCategory();
      expect(counts.byCategory, {'c1': 2});
      expect(counts.total, 3);
    });

    test('月份计数按本地时区分桶', () async {
      await repo.insertDiaries([
        makeDiary('a', '一', time: DateTime.utc(2026, 1, 10)),
        makeDiary('b', '二', time: DateTime.utc(2026, 1, 20)),
        makeDiary('c', '三', time: DateTime.utc(2026, 3, 1)),
      ]);
      final counts = await repo.diaryCountByMonth();
      final jan = DateTime.utc(2026, 1, 10).toLocal();
      expect(counts[DateTime(jan.year, jan.month)], 2);
    });

    test('旧格式闸门查询', () async {
      await repo.insertADiary(makeDiary('t', '一'));
      expect(await repo.hasLegacyFormatDiaries(), isFalse);
      await repo.insertADiary(
        makeDiary('legacy', '二').copyWith(type: 'richText'),
      );
      expect(await repo.hasLegacyFormatDiaries(), isTrue);
      expect((await repo.getLegacyFormatDiaries()).single.id, 'legacy');
    });
  });

  group('重建与修复', () {
    test('rebuildAllIndexes 幂等重灌', () async {
      await repo.insertDiaries([
        makeDiary('a', '苹果', linkTo: ['b']),
        makeDiary('b', '香蕉'),
      ]);
      final n = await repo.rebuildAllIndexes();
      expect(n, 2);
      expect((await search('苹果')).map((d) => d.id), ['a']);
      expect((await repo.getBacklinks('b')).map((d) => d.id), ['a']);
    });

    test('repairData 重推派生并修孤儿分类', () async {
      final broken = makeDiary(
        'd1',
        '正文 内容',
      ).copyWith(contentText: '陈旧 纯文本', categoryId: 'ghost-category');
      // 绕过派生断言的写入路径：skip 模式落一个派生已漂移的行。
      await repo.updateADiary(newDiary: broken, index: .skip);
      final report = await repo.repairData();
      expect(report.hasFix, isTrue);
      final fixed = (await repo.getDiaryByBusinessId('d1'))!;
      expect(fixed.contentText, '正文 内容');
      expect(fixed.categoryId, isNull);
    });
  });

  test('clearAll 清空后句柄仍可用', () async {
    await repo.insertADiary(makeDiary('d1', '苹果'));
    await db.clearAll();
    expect(await repo.getAllDiaries(), isEmpty);
    expect(await search('苹果'), isEmpty);
    await repo.insertADiary(makeDiary('d2', '香蕉'));
    expect((await search('香蕉')).map((d) => d.id), ['d2']);
  });
}
