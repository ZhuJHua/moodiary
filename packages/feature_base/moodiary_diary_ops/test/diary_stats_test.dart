import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'support.dart';

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository diaries;
  late CategoryRepository categories;
  late DiaryStatsOps stats;

  setUp(() {
    db = openTestDatabase();
    diaries = DiaryRepository(db);
    categories = CategoryRepository(db);
    stats = DiaryStatsOps(
      diaries: diaries,
      categories: categories,
      insights: MoodInsightsRepository(db),
    );
  });

  tearDown(() => db.close());

  test(
    'overview counts moods beyond a diary page, including future entries',
    () async {
      await diaries.insertDiaries([
        for (var index = 0; index < 10000; index++)
          makeDiary('recorded-$index', 'recorded', mood: DiaryMood.good),
        makeDiary(
          'oldest',
          'oldest',
          time: DateTime.utc(2020),
          mood: DiaryMood.bad,
        ),
        makeDiary(
          'future',
          'future',
          time: DateTime.now().add(const Duration(days: 365)),
        ),
        makeDiary('hidden', 'hidden', mood: DiaryMood.great, show: false),
      ]);

      final overview = await stats.overviewForModel();

      expect(overview.total, 10002);
      expect(overview.moods, {
        DiaryMood.good: 10000,
        DiaryMood.bad: 1,
        null: 1,
      });
      expect(overview.oldest, DateTime.utc(2020));
    },
  );
}
