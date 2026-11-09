import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';

import 'support.dart';

String monthKey(int year, int month) =>
    '${DateTime(year, month).year}-'
    '${DateTime(year, month).month.toString().padLeft(2, '0')}';

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

  test('months, older and future reconcile with visibleDiaries', () async {
    final now = DateTime.now();
    await diaries.insertDiaries([
      makeDiary('current', 'current', time: DateTime(now.year, now.month, 2)),
      makeDiary(
        'previous',
        'previous',
        time: DateTime(now.year, now.month - 1, 3),
      ),
      makeDiary(
        'two-ago',
        'two ago',
        time: DateTime(now.year, now.month - 2, 4),
      ),
      makeDiary('older', 'older', time: DateTime(now.year, now.month - 5, 5)),
      makeDiary('future', 'future', time: DateTime(now.year, now.month + 1, 6)),
      makeDiary(
        'recycled',
        'recycled',
        time: DateTime(now.year, now.month, 7),
        show: false,
      ),
    ]);

    final payload = await stats.statsPayload(months: 3);
    final months = (payload['months'] as List).cast<Map<String, dynamic>>();

    expect(payload['totalDiaries'], 6);
    expect(payload['visibleDiaries'], 5);
    expect(payload['recycleBinDiaries'], 1);
    expect(months, hasLength(3));
    expect(months[0]['month'], monthKey(now.year, now.month - 2));
    expect(months[1]['month'], monthKey(now.year, now.month - 1));
    expect(months[2]['month'], monthKey(now.year, now.month));
    expect([for (final row in months) row['diaries']], [1, 1, 1]);
    expect(payload['monthsWindow'], {
      'from': monthKey(now.year, now.month - 2),
      'to': monthKey(now.year, now.month),
    });
    expect(payload['olderDiaries'], 1);
    expect(payload['futureDiaries'], 1);

    final bucketSum = months.fold<int>(
      0,
      (sum, row) => sum + (row['diaries']! as int),
    );
    expect(
      bucketSum +
          (payload['olderDiaries']! as int) +
          (payload['futureDiaries']! as int),
      payload['visibleDiaries'],
    );
  });

  test('a one month window still reconciles', () async {
    final now = DateTime.now();
    await diaries.insertDiaries([
      makeDiary('current', 'current', time: DateTime(now.year, now.month, 2)),
      makeDiary(
        'previous',
        'previous',
        time: DateTime(now.year, now.month - 1, 3),
      ),
      makeDiary('future', 'future', time: DateTime(now.year, now.month + 1, 4)),
    ]);

    final payload = await stats.statsPayload(months: 1);
    final months = (payload['months'] as List).cast<Map<String, dynamic>>();

    expect(months, hasLength(1));
    expect(months.single['month'], monthKey(now.year, now.month));
    expect(months.single['diaries'], 1);
    expect(payload['olderDiaries'], 1);
    expect(payload['futureDiaries'], 1);
    expect(
      1 +
          (payload['olderDiaries']! as int) +
          (payload['futureDiaries']! as int),
      payload['visibleDiaries'],
    );
  });
}
