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
  group('从真实工具输出里抠日记引用', () {
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

    List<String> ids(List<DiaryCitation> c) => [for (final x in c) x.id];

    test('searchDiaries 列表：每篇一个 id，回收站不出现', () async {
      final out = await run(AssistantTool.searchDiaries, const {});
      final cited = diaryCitationsOf([
        _call(AssistantTool.searchDiaries.id, out),
      ]);
      expect(ids(cited), containsAll([a.id, b.id]));
      expect(cited.length, 2);
      expect(cited.every((c) => c.kind == .read), isTrue);
    });

    test('getDiary 全文：多篇合并去重，找不到的不算', () async {
      final query = await run(AssistantTool.searchDiaries, const {});
      final full = await run(AssistantTool.getDiary, {
        'ids': [a.id, hidden.id, 'nope'],
      });
      final cited = ids(
        diaryCitationsOf([
          _call(AssistantTool.searchDiaries.id, query),
          _call(AssistantTool.getDiary.id, full),
        ]),
      );
      expect(cited.where((id) => id == a.id).length, 1);
      expect(cited, isNot(contains(hidden.id)));
      expect(cited, isNot(contains('nope')));
    });

    test('写类工具：创建、修改、删除各自成组，写优先于读', () async {
      final created = await run(AssistantTool.createDiary, {
        'items': [
          {'title': '新的一篇', 'content': '正文'},
        ],
      });
      final updated = await run(AssistantTool.updateDiary, {
        'items': [
          {'id': a.id, 'title': '搬家（改）'},
          {'id': 'missing-id-0000000000', 'title': 'x'},
        ],
      });
      final deleted = await run(AssistantTool.deleteDiary, {
        'items': [
          {'id': b.id},
        ],
      });
      final query = await run(AssistantTool.searchDiaries, const {});
      final cited = diaryCitationsOf([
        _call(AssistantTool.searchDiaries.id, query),
        _call(AssistantTool.createDiary.id, created),
        _call(AssistantTool.updateDiary.id, updated),
        _call(AssistantTool.deleteDiary.id, deleted),
      ]);
      final byId = {for (final c in cited) c.id: c.kind};
      expect(byId[a.id], DiaryCitationKind.updated);
      expect(byId[b.id], DiaryCitationKind.deleted);
      expect(byId.values.where((k) => k == .created).length, 1);
      expect(byId.containsKey('missing-id-0000000000'), isFalse);
      expect(
        citesDiaries(_call(AssistantTool.createDiary.id, created)),
        isTrue,
      );
    });

    test('失败输出、没跑完的调用、非日记工具都不贡献引用', () async {
      final full = await run(AssistantTool.getDiary, {
        'ids': ['nope'],
      });
      expect(full, startsWith('Not found'));
      final query = await run(AssistantTool.searchDiaries, const {});
      expect(
        diaryCitationsOf([
          _call(AssistantTool.getDiary.id, full),
          _call(AssistantTool.searchDiaries.id, query, done: false),
          _call(AssistantTool.listCategories.id, 'id=${a.id} name=旅行'),
        ]),
        isEmpty,
      );
    });

    test('AssistantTurn 在恢复与工具完成两处派生，不落库', () async {
      final query = await run(AssistantTool.searchDiaries, const {});
      final call = _call(AssistantTool.searchDiaries.id, query);
      final record = ChatMessage(
        id: 'm1',
        sessionId: 's1',
        role: kRoleAssistant,
        content: '',
        createdAt: DateTime.utc(2026, 9, 13),
        toolCalls: [call],
      );
      final restored = AssistantTurn.fromRecord(record);
      expect(ids(restored.diaryCitations), containsAll([a.id, b.id]));
      expect(restored.toRecord('s1').toolCalls, [call]);

      final streaming = AssistantTurn.assistant('', streaming: true);
      expect(streaming.diaryCitations, isEmpty);
      expect(
        ids(streaming.copyWith(toolCalls: [call]).diaryCitations),
        containsAll([a.id, b.id]),
      );
      expect(streaming.copyWith(text: 'x').diaryCitations, isEmpty);
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
