import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';

class _SemanticIndex extends Fake implements EmbedIndexService {
  _SemanticIndex(this.ids);

  final List<String> ids;
  int calls = 0;

  @override
  bool get enabled => true;

  @override
  Future<List<SemanticHit>> search(
    String query, {
    int limit = 5,
    String? categoryId,
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    calls++;
    return [
      for (final id in ids.take(limit))
        (diaryId: id, distance: 0.25, startOff: 0, len: 1),
    ];
  }
}

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository repo;

  Diary diary(String title, String body) => Diary.create(
    title: title,
    content: body,
    contentText: body,
    mood: null,
    imageName: const [],
    audioName: const [],
    videoName: const [],
    tags: const [],
    type: .richText,
  );

  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    repo = DiaryRepository(db);
    getIt.registerSingleton<DiaryRepository>(repo);
  });

  tearDown(() async {
    await getIt.reset();
    await db.close();
  });

  Future<String> search(Map<String, dynamic> input) =>
      AssistantToolRegistry.byId(AssistantTool.searchDiaries.id)!.run(input);

  group('searchDiaries 合并后的输出契约', () {
    test('keyword output stays exact without an index', () async {
      await repo.insertADiary(
        diary(
          ' Orchard ',
          'A walk',
        ).copyWith(id: 'keyword', time: DateTime.utc(2026, 1, 1)),
      );
      expect(
        await search({'query': ' Orchard '}),
        '1 matches:\n'
        'id=keyword 【2026-01-01】Orchard mood=not recorded via=keyword\n'
        'A walk',
      );
      expect(
        await search({'query': 'missing'}),
        'No diaries match keywords "missing". Only the keyword path ran; '
        'the semantic index is off.',
      );
      expect(
        await search({'query': 'Orchard', 'mode': 'meaning'}),
        'No diaries yet. Only the keyword path ran; the semantic index is off.',
      );
    });

    test(
      'hybrid output keeps ranking, similarity and lower-bound text',
      () async {
        await repo.insertDiaries([
          diary(
            'Orchard',
            'A walk',
          ).copyWith(id: 'keyword', time: DateTime.utc(2026, 1, 1)),
          diary(
            'Orchard notes',
            'Fresh air',
          ).copyWith(id: 'shared', time: DateTime.utc(2026, 1, 2)),
          diary(
            'Spring',
            'Trees in bloom',
          ).copyWith(id: 'meaning', time: DateTime.utc(2026, 1, 3)),
        ]);
        final index = _SemanticIndex(['shared', 'meaning']);
        getIt.registerSingleton<EmbedIndexService>(index);

        expect(
          await search({'query': 'Orchard', 'sort': 'oldest', 'limit': 4}),
          '3 matches:\n'
          'id=shared 【2026-01-02】Orchard notes mood=not recorded via=keyword+meaning similarity=0.75\n'
          'Fresh air\n\n'
          'id=keyword 【2026-01-01】Orchard mood=not recorded via=keyword\n'
          'A walk\n\n'
          'id=meaning 【2026-01-03】Spring mood=not recorded via=meaning similarity=0.75\n'
          'Trees in bloom',
        );
        expect(
          await search({'query': 'Orchard', 'sort': 'oldest', 'limit': 2}),
          'at least 3 matches; the first 2 follow. Raise limit or '
          'narrow the filters for more.\n'
          'id=shared 【2026-01-02】Orchard notes mood=not recorded via=keyword+meaning similarity=0.75\n'
          'Fresh air\n\n'
          'id=keyword 【2026-01-01】Orchard mood=not recorded via=keyword\n'
          'A walk',
        );
        final calls = index.calls;
        final keyword = await search({'query': 'Orchard', 'mode': 'keyword'});
        expect(keyword, startsWith('2 matches:'));
        expect(keyword, isNot(contains('meaning')));
        expect(index.calls, calls);
        expect(await search({}), startsWith('3 matches:'));
        expect(index.calls, calls);
      },
    );

    test('empty semantic results retain the path messages', () async {
      getIt.registerSingleton<EmbedIndexService>(_SemanticIndex([]));
      expect(
        await search({'query': 'missing'}),
        'No diaries match keywords "missing". Both the keyword and the meaning path ran.',
      );
      expect(
        await search({'query': 'missing', 'mode': 'keyword'}),
        'No diaries match keywords "missing". Only the keyword path ran.',
      );
      expect(
        await search({'query': 'missing', 'mode': 'meaning'}),
        'No diaries yet. Both the keyword and the meaning path ran.',
      );
    });

    test('没有语义索引时只走关键词', () async {
      await repo.insertDiaries([diary('河边', '风 很大')]);
      final out = await search({'query': '河边'});
      expect(out, contains('via=keyword'));
      expect(out, isNot(contains('via=meaning')));
      expect(out, isNot(contains('similarity=')));
    });

    test('头行报总命中与是否只给了前几条', () async {
      await repo.insertDiaries([
        for (var i = 0; i < 5; i++) diary('跑步 $i', '今天 又去 跑步 了'),
      ]);
      expect(
        await search({'query': '跑步', 'limit': 2}),
        startsWith('5 matches; the first 2 follow'),
      );
      expect(await search({'query': '跑步'}), startsWith('5 matches:'));
    });

    test('正文只给摘录，全文走 getDiary', () async {
      await repo.insertDiaries([diary('长文', '啊' * 400)]);
      final out = await search({'query': '长文'});
      expect(out, contains('(excerpt; full text via getDiary)'));
    });

    test('空结果说明跑过哪条路', () async {
      await repo.insertDiaries([diary('河边', '风 很大')]);
      final out = await search({'query': '完全不存在的词'});
      expect(out, isNotEmpty);
      expect(out.toLowerCase(), contains('keyword'));
    });

    test('不给 query 时按条件浏览', () async {
      await repo.insertDiaries([diary('甲', '一'), diary('乙', '二')]);
      final out = await search({});
      expect(out, contains('via=keyword'));
      expect(out, contains('2 matches'));
    });
  });
}
