import 'package:drift/native.dart';
import 'package:fast_tokenizer/fast_tokenizer.dart' show TokenizeResult;
import 'package:fast_tokenizer/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';

Future<TokenizeResult> _fakeTokenize(String text) async {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return TokenizeResult(cut: words, cutForSearch: words);
}

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository repo;

  Diary diary(String title, String body) => Diary.create(
    title: title,
    content: '',
    contentText: body,
    mood: .neutral,
    imageName: const [],
    audioName: const [],
    videoName: const [],
    tags: const [],
    type: .richText,
  );

  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    installFakeFastTokenizer(_fakeTokenize);
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
    test('没有语义索引时只走关键词，不谎报语义命中', () async {
      await repo.insertDiaries([diary('河边', '风 很大')]);
      final out = await search({'query': '河边'});
      expect(out, contains('via=keyword'));
      expect(out, isNot(contains('via=meaning')));
      expect(out, isNot(contains('similarity=')));
    });

    test('头行报总命中，返回不全时说明只给了前几条', () async {
      await repo.insertDiaries([
        for (var i = 0; i < 5; i++) diary('跑步 $i', '今天 又去 跑步 了'),
      ]);
      expect(
        await search({'query': '跑步', 'limit': 2}),
        startsWith('5 matches; the first 2 follow'),
      );
      expect(await search({'query': '跑步'}), startsWith('5 matches:'));
    });

    test('正文只给摘录，全文要另外走 getDiary', () async {
      await repo.insertDiaries([diary('长文', '啊' * 400)]);
      final out = await search({'query': '长文'});
      expect(out, contains('(excerpt; full text via getDiary)'));
    });

    test('空结果说明两条路各跑了没有，不是空串', () async {
      await repo.insertDiaries([diary('河边', '风 很大')]);
      final out = await search({'query': '完全不存在的词'});
      expect(out, isNotEmpty);
      expect(out.toLowerCase(), contains('keyword'));
    });

    test('不给 query 时按条件浏览，仍然每行标出处', () async {
      await repo.insertDiaries([
        diary('甲', '一'),
        diary('乙', '二'),
      ]);
      final out = await search({});
      expect(out, contains('via=keyword'));
      expect(out, contains('2 matches'));
    });

    test('工具卡片摘要读的是 query，不是已经退役的 keywords', () {
      final spec = AssistantToolRegistry.byId(AssistantTool.searchDiaries.id)!;
      final summary = spec.summaryOf({'query': '跑步'}, '3 matches:\nid=x');
      expect(summary, contains('跑步'));
    });
  });
}
