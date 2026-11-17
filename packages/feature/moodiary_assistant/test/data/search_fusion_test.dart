import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    repo = DiaryRepository(db);
    getIt.registerSingleton<DiaryRepository>(repo);
    getIt.registerSingleton<CategoryRepository>(CategoryRepository(db));
    getIt.registerSingleton<MoodInsightsRepository>(MoodInsightsRepository(db));
  });
  tearDown(() async {
    await getIt.reset();
    await db.close();
  });
  Diary diary(String id, String title, int day) => Diary.create(
    title: title,
    content: 'A walk',
    contentText: 'A walk',
    imageName: const [],
    audioName: const [],
    videoName: const [],
    tags: const [],
    type: .richText,
  ).copyWith(id: id, time: DateTime.utc(2026, 1, day));
  Future<Map<String, dynamic>> search(Map<String, dynamic> args) async =>
      (jsonDecode(
        await AssistantToolRegistry.byId('search_diaries')!.run(args),
      ) as Map).cast<String, dynamic>();

  test('assistant passes semantic retrieval to shared search', () async {
    await repo.insertDiaries([
      diary('keyword', 'Orchard', 1),
      diary('shared', 'Orchard notes', 2),
      diary('meaning', 'Spring', 3),
    ]);
    final index = _SemanticIndex(['shared', 'meaning']);
    getIt.registerSingleton<EmbedIndexService>(index);
    final out = await search({'query': 'Orchard', 'limit': 4});
    expect(out['total'], 3);
    expect(out['totalIsLowerBound'], false);
    final hits = out['hits'] as List;
    expect(hits.first['id'], 'shared');
    expect(hits.first['via'], 'keyword+meaning');
    expect(hits.first['similarity'], .75);
    expect(hits.last['via'], 'meaning');
    expect(index.calls, 1);
  });
}
