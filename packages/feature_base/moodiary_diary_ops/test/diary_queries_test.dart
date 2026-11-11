import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';

import 'support.dart';

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository diaries;
  late DiaryQueries queries;

  setUp(() {
    db = openTestDatabase();
    diaries = DiaryRepository(db);
    queries = DiaryQueries(diaries: diaries);
  });

  tearDown(() => db.close());

  group('linkSummary', () {
    test('reports ids the body mentions but the table does not hold', () async {
      await diaries.insertDiaries([
        makeDiary('source', 'see', linkTo: ['known', 'missing-b', 'missing-a']),
        makeDiary('known', 'target'),
      ]);
      final diary = (await diaries.getDiaryByBusinessId('source'))!;

      final links = await queries.linkSummary(diary);

      expect(links['dangling'], ['missing-a', 'missing-b']);
      expect(
        [for (final entry in links['forward'] as List) (entry as Map)['id']],
        ['known'],
      );
    });

    test('a hidden diary is not a dangling target', () async {
      await diaries.insertDiaries([
        makeDiary('source', 'see', linkTo: ['recycled']),
        makeDiary('recycled', 'gone', show: false),
      ]);
      final diary = (await diaries.getDiaryByBusinessId('source'))!;

      final links = await queries.linkSummary(diary);

      expect(links['dangling'], isEmpty);
    });

    test('caps the dangling list at 100 plain ids', () async {
      final targets = [
        for (var i = 0; i < 105; i++) 'missing-${i.toString().padLeft(3, '0')}',
      ];
      await diaries.insertADiary(makeDiary('source', 'see', linkTo: targets));
      final diary = (await diaries.getDiaryByBusinessId('source'))!;

      final links = await queries.linkSummary(diary);

      final dangling = (links['dangling'] as List).cast<String>();
      expect(dangling, hasLength(100));
      expect(dangling, [...targets.take(100)]);
    });
  });
}
