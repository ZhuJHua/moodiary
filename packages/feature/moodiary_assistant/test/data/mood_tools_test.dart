import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository repo;
  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    repo = DiaryRepository(db);
    getIt.registerSingleton<DiaryRepository>(repo);
    getIt.registerSingleton<CategoryRepository>(CategoryRepository(db));
  });
  tearDown(() async {
    await getIt.reset();
    await db.close();
  });

  Future<String> run(AssistantTool tool, Map<String, dynamic> input) =>
      AssistantToolRegistry.byId(tool.id)!.run(input);

  test(
    'create defaults to unset; update can clear or preserve a mood',
    () async {
      await run(.createDiary, {
        'items': [
          {'content': 'unset'},
          {'content': 'set', 'mood': 'good'},
        ],
      });
      final diaries = await repo.getAllDiaries();
      final unset = diaries.singleWhere((d) => d.contentText == 'unset');
      final set = diaries.singleWhere((d) => d.contentText == 'set');
      expect(unset.mood, isNull);
      expect(set.mood, DiaryMood.good);
      await run(.updateDiary, {
        'items': [
          {'id': set.id, 'title': 'kept'},
        ],
      });
      expect((await repo.getDiaryByBusinessId(set.id))!.mood, DiaryMood.good);
      await run(.updateDiary, {
        'items': [
          {'id': set.id, 'mood': null},
        ],
      });
      expect((await repo.getDiaryByBusinessId(set.id))!.mood, isNull);
    },
  );

  test('overview includes all five levels and not recorded', () async {
    await repo.insertDiaries([
      for (final mood in [...DiaryMood.values, null])
        Diary.empty(type: .tiptap).copyWith(mood: mood),
    ]);
    final out = await run(.diaryOverview, {});
    for (final name in [
      'awful',
      'bad',
      'okay',
      'good',
      'great',
      'not recorded',
    ]) {
      expect(out, contains('$name=1'));
    }
    expect(out, isNot(contains('neutral')));
  });
}
