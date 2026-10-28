import 'dart:convert';

import 'package:drift/drift.dart'
    show ApplyInterceptor, OrderingTerm, QueryExecutor, QueryInterceptor, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

Diary makeDiary(
  String id,
  String text, {
  String? content,
  String? title,
  List<String> linkTo = const [],
  List<String> images = const [],
  List<String> audios = const [],
  List<String> videos = const [],
  List<String> files = const [],
  List<String> tags = const [],
  DateTime? time,
  String? categoryId,
  bool show = true,
}) {
  final doc =
      content ??
      jsonEncode({
        'type': 'doc',
        'attrs': {'v': 2},
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': text},
              for (final target in linkTo)
                {
                  'type': 'diaryLink',
                  'attrs': {'id': target, 'label': 'L'},
                },
            ],
          },
          for (final name in [...images, ...videos, ...audios])
            {
              'type': name.startsWith('image')
                  ? 'image'
                  : name.startsWith('video')
                  ? 'video'
                  : 'audio',
              'attrs': {'src': name},
            },
          for (final name in files)
            {
              'type': 'attachment',
              'attrs': {'src': name, 'name': name, 'mime': null, 'size': 1},
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
    mood: null,
    imageName: images,
    audioName: audios,
    videoName: videos,
    fileName: files,
    tags: tags,
    type: 'tiptap',
  );
}

String v1Doc(List<Map<String, dynamic>> content) =>
    jsonEncode({'type': 'doc', 'content': content});

String marked(String word) => '$searchHitStart$word$searchHitEnd';

String v2Doc(List<Map<String, dynamic>> content) => jsonEncode({
  'type': 'doc',
  'attrs': {'v': 2},
  'content': content,
});

Map<String, dynamic> audioNode(String src, [String? name]) => {
  'type': 'audio',
  'attrs': {'src': src, 'name': ?name},
};

List<Object?> audioNamesOf(Diary d) => [
  for (final node in (jsonDecode(d.content) as Map)['content'] as List)
    if (node['type'] == 'audio') node['attrs']['name'],
];

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository repo;

  setUpAll(() {
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
  });

  MoodiaryDatabase openDb() => MoodiaryDatabase.forTesting(
    NativeDatabase.memory(
      setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
    ),
  );

  void freshDatabasePerTest() {
    setUp(() {
      db = openDb();
      repo = DiaryRepository(db);
    });
    tearDown(() => db.close());
  }

  void oneDatabaseForGroup() {
    setUpAll(() {
      db = openDb();
      repo = DiaryRepository(db);
    });
    setUp(() => db.clearAll());
    tearDownAll(() => db.close());
  }

  Future<List<Diary>> search(String word) async => [
    for (final hit in await repo.searchDiaries(query: word)) hit.diary,
  ];

  group('保存只解析一次正文', () {
    freshDatabasePerTest();

    String fresh(String s) => String.fromCharCodes(s.codeUnits);
    Diary freshContent(Diary d) => d.copyWith(content: fresh(d.content));

    // 保存优化前的漏斗：每一步独立派生，归一改动时才重算媒体列。
    Diary oldRederived(Diary d) {
      final derived = DiaryContent.of(freshContent(d));
      final media = derived.media;
      return d.copyWith(
        contentText: derived.plainText,
        imageName: media.images,
        audioName: media.audios,
        videoName: media.videos,
        fileName: media.files,
      );
    }

    Diary oldCanonical(Diary input) {
      final d = freshContent(input);
      final content = d.type == 'tiptap'
          ? TiptapContent.normalize(d.content)
          : d.content;
      if (!identical(content, d.content)) {
        return oldRederived(d.copyWith(content: content));
      }
      final text = DiaryContent.of(freshContent(d)).plainText;
      return text == d.contentText ? d : d.copyWith(contentText: text);
    }

    List<Diary> fixtures() => [
      makeDiary(
        'v2',
        '过期纯文本',
        content: v2Doc([
          {
            'type': 'heading',
            'attrs': {'level': 2},
            'content': [
              {'type': 'text', 'text': '标题'},
            ],
          },
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': '正文'},
              for (final id in ['target-b', 'target-a', 'target-b'])
                {
                  'type': 'diaryLink',
                  'attrs': {'id': id, 'label': '链接'},
                },
            ],
          },
          for (final (type, src, name) in [
            ('image', 'image-b.jpg', '封面'),
            ('image', 'image-a.jpg', '内页'),
            ('image', 'image-b.jpg', '重复名'),
            ('video', 'video-a.mp4', '视频'),
            ('audio', 'audio-a.m4a', '录音'),
            ('attachment', 'file-a.pdf', '附件'),
          ])
            {
              'type': type,
              'attrs': {'src': src, 'name': name},
            },
        ]),
        images: ['image-b.jpg', 'image-a.jpg'],
        videos: ['video-a.mp4'],
        audios: ['audio-a.m4a'],
        files: ['file-a.pdf'],
        tags: ['乙', '甲', '乙'],
      ),
      makeDiary(
        'v1',
        '过期纯文本',
        content: v1Doc([
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': '旧版 image-legacy-rescue.jpg'},
              {
                'type': 'diaryLink',
                'attrs': {
                  'id': 'target-a',
                  'label': '链接',
                  'mentionSuggestionChar': '[',
                },
              },
            ],
          },
          audioNode('audio-old.m4a', '旧录音')
            ..['attrs'] = {'filename': 'audio-old.m4a', 'name': '旧录音'},
        ]),
        audios: ['audio-old.m4a'],
        images: ['image-legacy-rescue.jpg'],
        tags: ['旧版'],
      ),
      makeDiary(
        'salvage',
        '过期纯文本',
        content: v2Doc([
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': '仅在文字引用 image-rescue.jpg'},
            ],
          },
        ]),
        images: ['image-rescue.jpg'],
        tags: ['救回'],
      ),
      makeDiary(
        'rich',
        '过期纯文本',
        images: ['image-rich.jpg'],
        tags: ['富文本'],
      ).copyWith(
        type: 'richText',
        content: jsonEncode([
          {'insert': '富文本正文'},
          {
            'insert': {'image': 'image-rich.jpg'},
          },
          {'insert': '\n'},
        ]),
      ),
      makeDiary(
        'markdown',
        '过期纯文本',
        images: ['image-x.jpg'],
        tags: ['Markdown'],
      ).copyWith(type: 'markdown', content: '# 标题\n![](image-x.jpg)'),
    ];

    Future<void> expectStored(Diary expected) async {
      expect(await repo.getDiaryByBusinessId(expected.id), expected);
      final mediaNames = expected.type == 'tiptap'
          ? TiptapContent.parse(fresh(expected.content)).mediaNames
          : const <String, String>{};
      final expectedMedia = [
        for (final (kind, names) in [
          ('audio', expected.audioName),
          ('file', expected.fileName),
          ('image', expected.imageName),
          ('video', expected.videoName),
        ])
          for (var i = 0; i < names.length; i++)
            (kind, i, names[i], mediaNames[names[i]]),
      ];
      final media =
          await (db.select(db.diaryMedia)
                ..where((m) => m.diaryId.equals(expected.id))
                ..orderBy([
                  (m) => OrderingTerm.asc(m.kind),
                  (m) => OrderingTerm.asc(m.seq),
                ]))
              .get();
      expect(
        media.map((m) => (m.kind, m.seq, m.fileName, m.name)),
        expectedMedia,
      );
      final links =
          await (db.select(db.diaryLinks)
                ..where((l) => l.srcId.equals(expected.id))
                ..orderBy([(l) => OrderingTerm.asc(l.dstId)]))
              .get();
      final expectedLinks = DiaryContent.of(
        freshContent(expected),
      ).links.toList()..sort();
      expect(links.map((l) => (l.srcId, l.dstId)), [
        for (final id in expectedLinks) (expected.id, id),
      ]);
      final tags =
          await (db.select(db.diaryTags)
                ..where((t) => t.diaryId.equals(expected.id))
                ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
              .get();
      expect(tags.map((t) => (t.seq, t.tag)), [
        for (var i = 0; i < expected.tags.length; i++) (i, expected.tags[i]),
      ]);
    }

    for (final mode in ['insert', 'update-inline', 'update-skip']) {
      test('$mode：正文、媒体救回、子表和事件与旧算法完全一致', () async {
        final incoming = fixtures();
        final expected = incoming.map(oldCanonical).toList();
        if (mode != 'insert') {
          await repo.insertDiaries([
            for (final d in expected)
              makeDiary(
                d.id,
                '待替换',
                images: ['image-stale.jpg'],
                tags: ['待替换'],
                linkTo: mode == 'update-skip'
                    ? DiaryContent.of(freshContent(d)).links
                    : ['stale-target'],
              ),
          ]);
        }
        final events = <DiaryEvent>[];
        final sub = repo.diaryEvents.listen(events.add);
        addTearDown(sub.cancel);
        if (mode == 'insert') {
          await repo.insertDiaries(
            incoming.map(freshContent).toList(),
            index: .inline,
          );
        } else {
          for (final d in incoming) {
            await repo.updateADiary(
              newDiary: freshContent(d),
              index: mode == 'update-inline' ? .inline : .skip,
            );
          }
        }
        await pumpEventQueue();
        expect(events, hasLength(expected.length));
        expect(
          events.map(
            (e) => switch (e) {
              DiaryCreated(:final diary) when mode == 'insert' => diary,
              DiaryUpdated(:final diary) when mode != 'insert' => diary,
              _ => fail('保存事件类型错误：$e'),
            },
          ),
          expected,
        );
        for (final d in expected) {
          await expectStored(d);
        }
      });
    }

    test('编辑器派生媒体到 inline 更新只解析一次', () async {
      final d = freshContent(makeDiary('once', '正文', images: ['image-a.jpg']));
      final before = TiptapContent.parseCount;
      await repo.updateADiary(newDiary: withDerivedMedia(d), index: .inline);
      expect(TiptapContent.parseCount - before, 1);
    });

    test('批量插入每篇 v2 只解析一次，不依赖最近一次缓存', () async {
      final diaries = [
        for (var i = 0; i < 5; i++)
          freshContent(
            makeDiary(
              'batch-$i',
              '正文 $i',
              linkTo: ['target-$i'],
              images: ['image-$i.jpg'],
            ),
          ),
      ];
      final before = TiptapContent.parseCount;
      await repo.insertDiaries(diaries, index: .inline);
      expect(TiptapContent.parseCount - before, diaries.length);
    });

    for (final insert in [true, false]) {
      test('${insert ? '插入' : '更新'}旧版正文解析原串和归一后的串各一次', () async {
        final legacy = freshContent(fixtures()[1]);
        final before = TiptapContent.parseCount;
        if (insert) {
          await repo.insertADiary(legacy);
        } else {
          await repo.updateADiary(newDiary: withDerivedMedia(legacy));
        }
        expect(TiptapContent.parseCount - before, 2);
      });
    }
  });

  group('检索', () {
    freshDatabasePerTest();

    test('多词是 AND：每个词都要命中', () async {
      await repo.insertDiaries([
        makeDiary('d1', '苹果'),
        makeDiary('d2', '香蕉'),
        makeDiary('both', '苹果 香蕉'),
      ]);
      final hits = await repo.searchDiaries(query: '苹果 香蕉');
      expect(hits.map((h) => h.diary.id).toSet(), {'both'});
    });

    test('拼音与首字母命中中文，高亮落在原文上', () async {
      await repo.insertDiaries([makeDiary('d1', '今天吃了苹果')]);
      for (final q in ['pingguo', 'pg']) {
        final hit = (await repo.searchDiaries(query: q)).single;
        expect(hit.diary.id, 'd1', reason: q);
        expect(hit.excerpt, contains(marked('苹果')), reason: q);
      }
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
      final byCat = await repo.searchDiaries(query: '苹果', categoryId: 'c1');
      expect(byCat.map((h) => h.diary.id).toSet(), {'a', 'c'});
      final byTime = await repo.searchDiaries(
        query: '苹果',
        start: DateTime.utc(2026, 1, 15),
        end: DateTime.utc(2026, 2, 15),
      );
      expect(byTime.map((h) => h.diary.id), ['b']);
    });

    test('timeDesc/timeAsc 排序忽略相关性', () async {
      await repo.insertDiaries([
        makeDiary('old', '苹果 苹果 苹果', time: DateTime.utc(2026, 1, 1)),
        makeDiary('new', '苹果', time: DateTime.utc(2026, 5, 1)),
      ]);
      final desc = await repo.searchDiaries(query: '苹果', sort: .timeDesc);
      expect(desc.map((h) => h.diary.id), ['new', 'old']);
      final asc = await repo.searchDiaries(query: '苹果', sort: .timeAsc);
      expect(asc.map((h) => h.diary.id), ['old', 'new']);
    });

    test('整句查询切成词，命中处给出高亮与摘要', () async {
      await repo.insertADiary(
        makeDiary('d1', '早上吃了一个苹果，味道不错，然后去上班了', title: '关于苹果的日记'),
      );
      final hit = (await repo.searchDiaries(query: '苹果')).single;
      expect(hit.diary.id, 'd1');
      expect(hit.titleHighlight, '关于${marked('苹果')}的日记');
      expect(hit.excerpt, contains(marked('苹果')));
      expect(hit.excerpt, contains('味道'), reason: '摘要取自原文而非词串');
    });

    test('更新换索引：旧词摘除、新词可搜', () async {
      final d = makeDiary('d1', '苹果');
      await repo.insertADiary(d);
      await repo.updateADiary(
        newDiary: d.copyWith(contentText: '香蕉', content: '香蕉'),
      );
      expect(await search('苹果'), isEmpty);
      expect((await search('香蕉')).map((e) => e.id), ['d1']);
    });

    test('软删走查询期过滤，恢复后可搜', () async {
      final d = makeDiary('d1', '苹果');
      await repo.insertADiary(d);
      await repo.setVisibility(d, show: false);
      expect(await search('苹果'), isEmpty, reason: '回收站不进搜索结果');
      final restored = (await repo.getRecycleBinDiaries()).single;
      await repo.setVisibility(restored, show: true);
      expect((await search('苹果')).map((e) => e.id), ['d1']);
    });

    test('分页：总数不受页大小影响，翻页不重不漏', () async {
      await repo.insertDiaries([
        for (var i = 0; i < 7; i++)
          makeDiary('d$i', '苹果 第$i篇', time: DateTime.utc(2026, 1, i + 1)),
      ]);
      expect(await repo.countSearchDiaries(query: '苹果'), 7);

      final first = await repo.searchDiaries(query: '苹果', limit: 3);
      final second = await repo.searchDiaries(query: '苹果', limit: 3, offset: 3);
      final rest = await repo.searchDiaries(query: '苹果', limit: 3, offset: 6);
      expect([first, second, rest].map((p) => p.length), [3, 3, 1]);

      final ids = [
        for (final page in [first, second, rest])
          for (final hit in page) hit.diary.id,
      ];
      expect(ids.toSet(), hasLength(7));
      final whole = await repo.searchDiaries(query: '苹果');
      expect(ids, [for (final hit in whole) hit.diary.id], reason: '与不分页同序');
    });

    test('媒体名带标记进纯文本：可搜、摘要带标记，但不计字数', () async {
      final content = v2Doc([
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': '今天'},
          ],
        },
        audioNode('audio-1.m4a', '海边录音'),
        {
          'type': 'attachment',
          'attrs': {
            'src': 'file-1.pdf',
            'name': '旅行计划.pdf',
            'mime': null,
            'size': 1,
          },
        },
        {
          'type': 'image',
          'attrs': {'src': 'image-1.jpg', 'alt': '落日'},
        },
      ]);
      await repo.insertADiary(
        makeDiary(
          'd1',
          '今天',
          content: content,
          images: ['image-1.jpg'],
          audios: ['audio-1.m4a'],
          files: ['file-1.pdf'],
        ),
      );
      final row = await (db.select(
        db.diaries,
      )..where((d) => d.id.equals('d1'))).getSingle();
      expect(
        row.contentText,
        '今天\n\uFDD3海边录音\uFDD0\n\uFDD4旅行计划.pdf\uFDD0\n\uFDD1落日\uFDD0',
      );
      expect(TiptapContent.countCharacters(row.contentText), 2);
      final hit = (await repo.searchDiaries(query: '海边')).single;
      expect(hit.diary.id, 'd1');
      expect(hit.excerpt, contains('\uFDD3${marked('海边')}录音\uFDD0'));
      for (final q in ['旅行计划', '落日']) {
        expect((await search(q)).map((d) => d.id), ['d1'], reason: q);
      }
    });

    test('调用方带来的 contentText 不被信任，写库时按正文重新生成', () async {
      await repo.insertADiary(
        makeDiary('d1', '正文').copyWith(contentText: '正文\n\uFDD1伪造\uFDD0'),
      );
      final stored = (await repo.getDiaryByBusinessId('d1'))!;
      expect(stored.contentText, '正文');
      expect(await search('伪造'), isEmpty);
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
    oneDatabaseForGroup();

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

    test('placeId/weather 往返（含 null）', () async {
      final withMeta = makeDiary('d1', '正文').copyWith(
        placeId: 'p-xiamen',
        weather: const DiaryWeather(icon: '100', temp: '26', text: '晴'),
      );
      await repo.insertADiary(withMeta);
      await repo.insertADiary(makeDiary('d2', '正文'));
      final a = (await repo.getDiaryByBusinessId('d1'))!;
      expect(a.placeId, 'p-xiamen');
      expect(a.weather?.text, '晴');
      final b = (await repo.getDiaryByBusinessId('d2'))!;
      expect(b.placeId, isNull);
      expect(b.weather, isNull);
    });

    test('placeFootprints 按地点聚合篇数与首末时间，跳过回收站', () async {
      DateTime at(int day) => DateTime.utc(2025, 3, day, 8);
      for (final (id, day, show) in [
        ('a', 3, true),
        ('b', 9, true),
        ('c', 20, false),
      ]) {
        await repo.insertADiary(
          makeDiary(
            id,
            '正文',
            time: at(day),
            show: show,
          ).copyWith(placeId: 'p1'),
        );
      }
      final footprint = (await repo.placeFootprints())['p1']!;
      expect(footprint.count, 2);
      expect(footprint.first, at(3));
      expect(footprint.last, at(9));
      expect((await repo.getDiariesAtPlace('p1')).map((d) => d.id), ['b', 'a']);
    });

    test('手选天气没有温度：weather_temp 存 NULL 且读回不炸', () async {
      await repo.insertADiary(
        makeDiary('manual', '正文').copyWith(
          weather: const DiaryWeather(icon: '305', text: '小雨'),
        ),
      );
      final got = (await repo.getDiaryByBusinessId('manual'))!;
      expect(got.weather?.icon, '305');
      expect(got.weather?.text, '小雨');
      expect(got.weather?.temp, isNull);
      expect(got.weather?.displayText, '小雨');
      expect(got.weather?.compactText, '小雨');
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

    test('collectReferencedMedia 汇总含回收站，附件进 files', () async {
      await repo.insertDiaries([
        makeDiary('a', '正文', images: ['image-1.jpg']),
        makeDiary('b', '正文', audios: ['audio-1.m4a'], show: false),
        makeDiary('c', '正文', files: ['file-1.pdf'], show: false),
      ]);
      final refs = await repo.collectReferencedMedia();
      expect(refs.images, {'image-1.jpg'});
      expect(refs.audios, {'audio-1.m4a'});
      expect(refs.files, {'file-1.pdf'});
    });

    test('附件以 kind=file 存子表并保序往返，媒体查询按 file 过滤', () async {
      await repo.insertDiaries([
        makeDiary(
          'f',
          '正文',
          files: ['file-b.pdf', 'file-a.zip'],
          time: DateTime.utc(2026, 1, 2),
        ),
        makeDiary('i', '正文', images: ['image-1.jpg']),
      ]);
      final got = (await repo.getDiaryByBusinessId('f'))!;
      expect(got.fileName, ['file-b.pdf', 'file-a.zip']);
      final rows = await (db.select(
        db.diaryMedia,
      )..where((m) => m.diaryId.equals('f'))).get();
      expect(rows.map((r) => r.kind).toSet(), {'file'});
      expect((await repo.getMediaItems(type: .file)).map((m) => m.fileName), [
        'file-b.pdf',
        'file-a.zip',
      ]);
      expect((await repo.getMediaSourceDiaries(type: .file)).map((d) => d.id), [
        'f',
      ]);
      expect(await repo.getMediaItems(type: .image), hasLength(1));
    });

    test('collectReferencedMedia 含助手聊天图片', () async {
      await db
          .into(db.chatSessions)
          .insert(
            ChatSessionsCompanion.insert(
              id: 's1',
              title: const Value('会话'),
              providerId: 'p',
              model: 'm',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await db
          .into(db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              id: 'm1',
              sessionId: 's1',
              role: 'user',
              content: '看看这张图',
              createdAt: 0,
              imageName: const Value('image-chat.jpg'),
            ),
          );

      final refs = await repo.collectReferencedMedia();
      expect(refs.images, contains('image-chat.jpg'));
    });
  });

  group('媒体改名', () {
    freshDatabasePerTest();

    test('renameMedia 改写全部引用日记的节点名，算用户编辑', () async {
      final before = DateTime.utc(2026, 1, 1);
      await repo.insertDiaries([
        makeDiary('a', '一', audios: ['audio-1.m4a']),
        makeDiary(
          'b',
          '二',
          audios: ['audio-1.m4a', 'audio-2.m4a'],
          show: false,
        ),
        makeDiary('c', '三', audios: ['audio-2.m4a']),
      ]);
      final events = <DiaryEvent>[];
      final sub = repo.diaryEvents.listen(events.add);
      expect(await repo.renameMedia(.audio, 'audio-1.m4a', '  海边录音 '), 2);
      await pumpEventQueue();
      await sub.cancel();

      expect(events.map((e) => (e as DiaryUpdated).diary.id).toSet(), {
        'a',
        'b',
      });
      expect(events.any((e) => e.fromSync), isFalse);
      final a = (await repo.getDiaryByBusinessId('a'))!;
      final b = (await repo.getDiaryByBusinessId('b'))!;
      final c = (await repo.getDiaryByBusinessId('c'))!;
      expect(audioNamesOf(a), ['海边录音']);
      expect(audioNamesOf(b), ['海边录音', null]);
      expect(a.lastModified.isAfter(before), isTrue);
      expect(c.lastModified, before);
      expect(a.contentText, '一\n\uFDD3海边录音\uFDD0');
      expect(
        events.map((e) => (e as DiaryUpdated).diary.contentText),
        everyElement(contains('海边录音')),
        reason: '事件里的日记和库里一致',
      );
      expect((await search('海边')).map((d) => d.id), ['a']);

      expect(await repo.renameMedia(.audio, 'audio-1.m4a', ' '), 2);
      expect(audioNamesOf((await repo.getDiaryByBusinessId('a'))!), [null]);
      expect((await repo.getDiaryByBusinessId('a'))!.contentText, '一');
      expect(await search('海边'), isEmpty);
      expect(await repo.renameMedia(.audio, 'audio-1.m4a', null), 0);
    });

    test('diary_media 跟着正文记名称，改名后媒体列表同步', () async {
      await repo.insertDiaries([
        makeDiary(
          'a',
          '一',
          content: v2Doc([
            audioNode('audio-1.m4a', ' 晨间 '),
            {
              'type': 'image',
              'attrs': {'src': 'image-1.jpg'},
            },
            {
              'type': 'attachment',
              'attrs': {'src': 'file-1.pdf', 'name': '计划.pdf'},
            },
          ]),
          audios: ['audio-1.m4a'],
          images: ['image-1.jpg'],
          files: ['file-1.pdf'],
        ),
      ]);
      Future<List<(String, String?)>> items(MediaType type) async => [
        for (final i in await repo.getMediaItems(type: type))
          (i.fileName, i.name),
      ];
      expect(await items(.audio), [('audio-1.m4a', '晨间')]);
      expect(await items(.image), [('image-1.jpg', null)]);
      expect(await items(.file), [('file-1.pdf', '计划.pdf')]);

      expect(await repo.renameMedia(.image, 'image-1.jpg', '日落'), 1);
      expect(await repo.renameMedia(.file, 'file-1.pdf', '旅行.pdf'), 1);
      expect(await repo.renameMedia(.audio, 'image-1.jpg', '错类型'), 0);
      expect(await items(.image), [('image-1.jpg', '日落')]);
      expect(await items(.file), [('file-1.pdf', '旅行.pdf')]);
      expect(
        (await repo.getDiaryByBusinessId('a'))!.contentText,
        '\uFDD3晨间\uFDD0\n\uFDD1日落\uFDD0\n\uFDD4旅行.pdf\uFDD0',
      );
    });
  });

  group('删除与墓碑', () {
    freshDatabasePerTest();

    test('永久删除：行硬删 + 墓碑 + 索引摘除', () async {
      await repo.insertADiary(makeDiary('d1', '苹果'));
      expect(await repo.deleteADiary('d1'), isTrue);
      expect(await repo.getDiaryByBusinessId('d1'), isNull);
      expect(await search('苹果'), isEmpty);
      final tombstone = await TombstoneRepository(db)
          .getByKey(SyncTombstone.diaryKey('d1'));
      expect(tombstone, isNotNull);
    });

    test('复活闸门：重插同 id 清墓碑', () async {
      await repo.insertADiary(makeDiary('d1', '苹果'));
      await repo.tombstoneDiaryForSync(makeDiary('d1', '苹果'));
      await repo.insertADiary(makeDiary('d1', '苹果'));
      final tombstone = await TombstoneRepository(db)
          .getByKey(SyncTombstone.diaryKey('d1'));
      expect(tombstone, isNull);
    });

    test('deleteDiariesByIds 不留墓碑', () async {
      await repo.insertDiaries([makeDiary('a', '一'), makeDiary('b', '二')]);
      await repo.deleteDiariesByIds(['a', 'b']);
      expect(await repo.getAllDiaries(), isEmpty);
      expect(await TombstoneRepository(db).getAll(), isEmpty);
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
    oneDatabaseForGroup();

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
    oneDatabaseForGroup();

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

  group('内容 schema v2', () {
    freshDatabasePerTest();

    final v1 = v1Doc([
      {
        'type': 'paragraph',
        'content': [
          {'type': 'text', 'text': '  早'},
          {
            'type': 'diaryLink',
            'attrs': {'id': 'x', 'label': '', 'mentionSuggestionChar': '['},
          },
        ],
      },
      {'type': 'horizontalRule'},
      {
        'type': 'audio',
        'attrs': {'filename': 'audio-1.m4a'},
      },
      {'type': 'paragraph'},
    ]);
    final stamp = DateTime.utc(2025, 6, 1, 8);

    Diary legacyShaped(String id) =>
        makeDiary(id, '旧版纯文本', content: v1, audios: const [], time: stamp);

    Future<void> rawInsert(Diary d) async {
      await db
          .into(db.diaries)
          .insert(
            DiariesCompanion.insert(
              id: d.id,
              title: d.title,
              content: d.content,
              contentText: d.contentText,
              time: stamp.microsecondsSinceEpoch,
              lastModified: stamp.microsecondsSinceEpoch,
              show: 1,
              moodLevel: Value(d.mood?.score),
              type: d.type,
            ),
          );
    }

    void expectV2(Diary d) {
      final doc = jsonDecode(d.content) as Map<String, dynamic>;
      expect(doc['attrs'], {'v': 2});
      expect(d.content, isNot(contains('filename')));
      expect(d.content, isNot(contains('mentionSuggestionChar')));
      expect(d.contentText, '  早x\n');
      expect(d.audioName, ['audio-1.m4a']);
      expect(d.lastModified, stamp);
    }

    test('insert 漏斗：v1 正文落库即 v2，派生重算，lastModified 不动', () async {
      final events = <DiaryEvent>[];
      final sub = repo.diaryEvents.listen(events.add);
      await repo.insertADiary(legacyShaped('a'), fromSync: true);
      await pumpEventQueue();
      await sub.cancel();
      expectV2((await repo.getDiaryByBusinessId('a'))!);
      expectV2((events.single as DiaryCreated).diary);
      expect((await repo.getBacklinks('x')).map((d) => d.id), ['a']);
    });

    test('update 漏斗同样归一，index: skip 也不例外', () async {
      await repo.updateADiary(newDiary: legacyShaped('a'), index: .skip);
      expectV2((await repo.getDiaryByBusinessId('a'))!);
    });

    test('已是 v2 的正文原样落库，旧格式类型不碰', () async {
      final v2 = makeDiary('v2', '正文', images: ['image-1.jpg']);
      final rich = makeDiary(
        'rich',
        '旧',
      ).copyWith(type: 'richText', content: '[{"insert":"旧\\n"}]');
      await repo.insertDiaries([v2, rich]);
      expect((await repo.getDiaryByBusinessId('v2'))!.content, v2.content);
      expect((await repo.getDiaryByBusinessId('rich'))!.content, rich.content);
    });

    test('upgradeContentSchema：批量归一、重算派生与索引，不动 lastModified，可重跑', () async {
      for (var i = 0; i < 5; i++) {
        await rawInsert(legacyShaped('d$i'));
      }
      await rawInsert(makeDiary('ok', '已是新版'));
      final progress = <(int, int)>[];
      final events = <DiaryEvent>[];
      final sub = repo.diaryEvents.listen(events.add);
      final changed = await repo.upgradeContentSchema(
        batchSize: 2,
        onProgress: (done, total) => progress.add((done, total)),
      );
      await pumpEventQueue();
      await sub.cancel();

      expect(changed, 5);
      expect(progress.first, (0, 6));
      expect(progress.last, (6, 6));
      for (var i = 0; i < 5; i++) {
        expectV2((await repo.getDiaryByBusinessId('d$i'))!);
      }
      expect(events.every((e) => e is DiaryUpdated && e.fromSync), isTrue);
      expect(events, hasLength(5));
      expect((await search('早')).map((d) => d.id).toSet(), {
        for (var i = 0; i < 5; i++) 'd$i',
      });
      expect((await repo.getBacklinks('x')), hasLength(5));
      expect(await repo.upgradeContentSchema(), 0);
    });

    test('upgradeContentSchema：读后被同步改写或删除的行不回写旧副本', () async {
      final race = _AfterBatchRead();
      await db.close();
      db = MoodiaryDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
        ).interceptWith(race),
      );
      repo = DiaryRepository(db);
      for (final id in ['a', 'b', 'c']) {
        await rawInsert(legacyShaped(id));
      }
      final pulled = makeDiary('a', '远端新版', time: DateTime.utc(2026, 2, 1));
      race.pending = () async {
        await repo.insertADiary(pulled, fromSync: true);
        await repo.deleteDiariesByIds(['b']);
      };

      expect(await repo.upgradeContentSchema(), 1);
      expect(race.pending, isNull);
      final a = (await repo.getDiaryByBusinessId('a'))!;
      expect(a.content, pulled.content);
      expect(a.lastModified, pulled.lastModified);
      expect(await repo.getDiaryByBusinessId('b'), isNull);
      expectV2((await repo.getDiaryByBusinessId('c'))!);
    });
  });

  group('重建与修复', () {
    freshDatabasePerTest();

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
      await repo.updateADiary(newDiary: broken, index: .skip);
      final report = await repo.repairData();
      expect(report.hasFix, isTrue);
      final fixed = (await repo.getDiaryByBusinessId('d1'))!;
      expect(fixed.contentText, '正文 内容');
      expect(fixed.categoryId, isNull);
    });

    test('repairData 补回纯文本里缺的媒体名', () async {
      await repo.insertADiary(
        makeDiary(
          'd1',
          '正文',
          content: v2Doc([audioNode('audio-1.m4a', '海边录音')]),
          audios: ['audio-1.m4a'],
        ).copyWith(contentText: ''),
      );
      await (db.update(db.diaries)..where((d) => d.id.equals('d1'))).write(
        const DiariesCompanion(contentText: Value('正文')),
      );
      expect(await search('海边'), isEmpty);
      final report = await repo.repairData();
      expect(report.changed, 1);
      expect((await search('海边')).map((d) => d.id), ['d1']);
    });
  });

  test('clearAll 清空后句柄仍可用', () async {
    db = openDb();
    addTearDown(db.close);
    repo = DiaryRepository(db);
    await repo.insertADiary(makeDiary('d1', '苹果'));
    await db.clearAll();
    expect(await repo.getAllDiaries(), isEmpty);
    expect(await search('苹果'), isEmpty);
    await repo.insertADiary(makeDiary('d2', '香蕉'));
    expect((await search('香蕉')).map((d) => d.id), ['d2']);
  });
}

class _AfterBatchRead extends QueryInterceptor {
  Future<void> Function()? pending;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await super.runSelect(executor, statement, args);
    final run = pending;
    if (run != null && statement.contains('FROM "diaries" WHERE')) {
      pending = null;
      await run();
    }
    return rows;
  }
}
