import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';
import 'package:moodiary_assistant/src/application/diary_citation.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';

AssistantToolCall _call(String name, String result, {bool done = true}) =>
    AssistantToolCall(
      callId: 'c-$name',
      name: name,
      result: result,
      done: done,
    );

void main() {
  group('从真实工具输出里抠 id', () {
    late MoodiaryDatabase db;
    late DiaryRepository repo;
    late Diary a;
    late Diary b;
    late Diary hidden;

    Diary diary(String title, {bool show = true}) => Diary.create(
      title: title,
      content: '',
      contentText: '$title 的正文',
      mood: .neutral,
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: const [],
      type: .richText,
    ).copyWith(show: show);

    setUp(() async {
      db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
      repo = DiaryRepository(db);
      getIt.registerSingleton<DiaryRepository>(repo);
      a = diary('搬家');
      b = diary('加班');
      hidden = diary('回收站里的', show: false);
      await repo.insertDiaries([a, b, hidden], index: .skip);
    });

    tearDown(() async {
      await getIt.reset();
      await db.close();
    });

    Future<String> run(AssistantTool tool, Map<String, dynamic> input) =>
        AssistantToolRegistry.byId(tool.id)!.run(input);

    test('queryDiaries 列表：每篇一个 id，顺序保持，回收站不出现', () async {
      final out = await run(AssistantTool.queryDiaries, const {});
      final ids = citedDiaryIdsOf([_call(AssistantTool.queryDiaries.id, out)]);
      expect(ids, containsAll([a.id, b.id]));
      expect(ids, isNot(contains(hidden.id)));
      expect(ids.length, 2);
    });

    test('getDiary 全文：多篇合并去重，找不到的不算', () async {
      final query = await run(AssistantTool.queryDiaries, const {});
      final full = await run(AssistantTool.getDiary, {
        'ids': [a.id, hidden.id, 'nope'],
      });
      final ids = citedDiaryIdsOf([
        _call(AssistantTool.queryDiaries.id, query),
        _call(AssistantTool.getDiary.id, full),
      ]);
      expect(ids.where((id) => id == a.id).length, 1);
      expect(ids, isNot(contains(hidden.id)));
      expect(ids, isNot(contains('nope')));
    });

    test('失败输出、没跑完的调用、非读类工具都不贡献 id', () async {
      final full = await run(AssistantTool.getDiary, {
        'ids': ['nope'],
      });
      expect(full, startsWith('Not found'));
      final query = await run(AssistantTool.queryDiaries, const {});
      expect(
        citedDiaryIdsOf([
          _call(AssistantTool.getDiary.id, full),
          _call(AssistantTool.queryDiaries.id, query, done: false),
          _call(AssistantTool.listCategories.id, 'id=cat name=旅行'),
        ]),
        isEmpty,
      );
    });

    test('AssistantTurn 在恢复与工具完成两处派生，不落库', () async {
      final query = await run(AssistantTool.queryDiaries, const {});
      final call = _call(AssistantTool.queryDiaries.id, query);
      final record = ChatMessage(
        id: 'm1',
        sessionId: 's1',
        role: kRoleAssistant,
        content: '',
        createdAt: DateTime.utc(2026, 9, 13),
        toolCalls: [call],
      );
      final restored = AssistantTurn.fromRecord(record);
      expect(restored.citedDiaryIds, containsAll([a.id, b.id]));
      expect(restored.toRecord('s1').toolCalls, [call]);

      final streaming = AssistantTurn.assistant('', streaming: true);
      expect(streaming.citedDiaryIds, isEmpty);
      expect(
        streaming.copyWith(toolCalls: [call]).citedDiaryIds,
        containsAll([a.id, b.id]),
      );
      expect(streaming.copyWith(text: 'x').citedDiaryIds, isEmpty);
    });
  });

  group('用户消息里的日记引用', () {
    test('引用标记往返，正文原样', () {
      final cited = citeDiary('这篇写得怎么样', 'd-1');
      expect(splitDiaryCitation(cited), (diaryId: 'd-1', text: '这篇写得怎么样'));
      expect(splitDiaryCitation('普通消息'), (diaryId: null, text: '普通消息'));
      expect(splitDiaryCitation('[diary:'), (diaryId: null, text: '[diary:'));
      expect(splitDiaryCitation('[diary:]x'), (
        diaryId: null,
        text: '[diary:]x',
      ));
    });

    test('给模型的版本把标记换成读日记的指令', () {
      final forModel = diaryCitationForModel(citeDiary('怎么样', 'd-1'));
      expect(forModel, contains('id=d-1'));
      expect(forModel, contains('getDiary'));
      expect(forModel, endsWith('怎么样'));
      expect(diaryCitationForModel('普通消息'), '普通消息');
    });
  });
}
