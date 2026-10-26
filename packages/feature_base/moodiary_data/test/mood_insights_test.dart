import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

MoodInsightEntry entry(
  int day,
  DiaryMood? mood, {
  List<String> tags = const [],
}) => MoodInsightEntry(
  id: '$day-${mood?.name}',
  time: DateTime(2026, 10, day, 13),
  mood: mood,
  tags: tags,
);

void main() {
  test('day key converts UTC instants to local calendar dates', () {
    final instant = DateTime.utc(2026, 10, 21, 23, 30);
    final local = instant.toLocal();
    expect(moodDayKey(instant), DateTime(local.year, local.month, local.day));
  });

  test(
    'day average excludes null moods; period mean gives each day equal weight',
    () {
      final result = summarizeMood([
        entry(1, .awful),
        entry(1, .awful),
        entry(1, null),
        entry(2, .great),
        entry(3, null),
      ]);
      expect(result.days[DateTime(2026, 10, 1)]!.average, 1);
      expect(result.average, 3); // entry-weighted mean would be 7/3
      expect(result.recordedDays, 2);
      expect(result.entryCount, 5);
      expect(result.distribution[DiaryMood.awful], 2);
      expect(result.distribution[DiaryMood.great], 1);
      expect(result.distribution.values.reduce((a, b) => a + b), 3);
    },
  );

  test(
    'longest streak rounds half up, breaks on gaps, nulls and low moods',
    () {
      final result = summarizeMood([
        entry(1, .okay), entry(1, .good), // 3.5 => good
        entry(2, .great), entry(3, null), entry(4, .good),
        entry(6, .good), entry(7, .great), entry(8, .good),
        entry(9, .okay), entry(10, .great),
      ]);
      expect(moodLevel(3.5), DiaryMood.good);
      expect(result.longestGoodStreak, 3);
    },
  );

  test('streak continues across month and year boundaries', () {
    final crossYear = summarizeMood([
      MoodInsightEntry(id: 'a', time: DateTime(2025, 12, 31), mood: .good),
      MoodInsightEntry(id: 'b', time: DateTime(2026, 1, 1), mood: .great),
    ]);
    expect(crossYear.longestGoodStreak, 2);
  });

  test('weekday window is half-open, Sunday first, averaged by day', () {
    final rows = [
      entry(11, .awful),
      entry(18, .awful),
      entry(18, .great),
      entry(19, .good),
      entry(25, .great),
      entry(26, .awful),
      entry(20, null),
    ];
    final values = moodWeekdayAverages(
      rows,
      start: DateTime(2026, 10, 18),
      end: DateTime(2026, 10, 26),
    );
    expect(values, [4, 4, null, null, null, null, null]);
  });

  test(
    'month and year averages weigh recorded days, not entries or months',
    () {
      final rows = [
        MoodInsightEntry(id: 'a', time: DateTime(2024, 1, 1), mood: .awful),
        MoodInsightEntry(id: 'b', time: DateTime(2024, 1, 1, 20), mood: .awful),
        MoodInsightEntry(id: 'c', time: DateTime(2024, 1, 2), mood: .great),
        MoodInsightEntry(id: 'd', time: DateTime(2024, 1, 3)),
        MoodInsightEntry(id: 'e', time: DateTime(2024, 2, 29), mood: .great),
        MoodInsightEntry(id: 'f', time: DateTime(2024, 3)),
        MoodInsightEntry(id: 'g', time: DateTime(2025, 1, 1), mood: .good),
        MoodInsightEntry(id: 'h', time: DateTime(2023, 12, 31)),
      ];
      final months = moodMonthAverages(rows.reversed);
      final years = moodYearAverages(rows.reversed);
      expect(months, {
        DateTime(2023, 12): null,
        DateTime(2024, 1): 3.0,
        DateTime(2024, 2): 5.0,
        DateTime(2024, 3): null,
        DateTime(2025, 1): 4.0,
      });
      expect(years[DateTime(2024)], closeTo(11 / 3, .00001));
      expect(years[DateTime(2025)], 4);
      expect(years[DateTime(2023)], isNull);
      for (final month in months.keys) {
        expect(
          months[month],
          summarizeMood(
            rows.where((e) {
              final day = moodDayKey(e.time);
              return day.year == month.year && day.month == month.month;
            }),
          ).average,
        );
      }
      expect(moodMonthAverages([]), isEmpty);
      expect(moodYearAverages([]), isEmpty);
    },
  );

  test('month and year keys use local calendar dates for UTC entries', () {
    final instant = DateTime.utc(2025, 12, 31, 23, 30);
    final local = instant.toLocal();
    final rows = [MoodInsightEntry(id: 'utc', time: instant, mood: .good)];
    expect(moodMonthAverages(rows), {DateTime(local.year, local.month): 4.0});
    expect(moodYearAverages(rows), {DateTime(local.year): 4.0});
  });

  test('tags require five mood entries; delta is entry weighted and tags deduplicated', () {
    final rows = [
      for (var i = 0; i < 5; i++) entry(i + 1, .great, tags: ['up', 'up']),
      for (var i = 0; i < 5; i++) entry(i + 6, .awful, tags: ['down']),
      for (var i = 0; i < 4; i++) entry(i + 11, .okay, tags: ['small']),
      entry(20, null, tags: ['small']),
    ];
    final tags = moodTagDeltas(rows);
    expect(tags.map((e) => e.tag), ['down', 'up']);
    expect(tags.map((e) => e.count), [5, 5]);
    expect(tags.map((e) => e.delta), [-2, 2]);
  });

  test('tags sorted by absolute delta and limited to seven', () {
    final rows = [
      for (var i = 0; i < 5; i++)
        entry(
          i + 1,
          .great,
          tags: [for (var tag = 0; tag < 9; tag++) 'tag$tag'],
        ),
      for (var i = 0; i < 5; i++) entry(i + 10, .awful),
    ];
    final tags = moodTagDeltas(rows);
    expect(tags.length, 7);
    expect(tags.every((e) => e.delta == 2), isTrue);
    final varying = moodTagDeltas([
      for (var i = 0; i < 5; i++) entry(i + 1, .great, tags: ['high']),
      for (var i = 0; i < 5; i++) entry(i + 6, .good, tags: ['middle']),
      for (var i = 0; i < 10; i++) entry(i + 11, .awful, tags: ['low']),
    ]);
    expect(varying.map((e) => e.tag), ['high', 'low', 'middle']);
  });

  test(
    'Sunday-first week bounds include Sunday, cross months, and are half-open',
    () {
      final sunday = moodPeriodBounds(DateTime(2026, 10, 18, 16), .week);
      final saturday = moodPeriodBounds(DateTime(2026, 10, 24), .week);
      expect(sunday, (
        start: DateTime(2026, 10, 18),
        end: DateTime(2026, 10, 25),
      ));
      expect(saturday, sunday);
      expect(moodPeriodBounds(DateTime(2026, 1, 1), .week), (
        start: DateTime(2025, 12, 28),
        end: DateTime(2026, 1, 4),
      ));
      expect(moodPeriodBounds(DateTime(2024, 2, 29), .month), (
        start: DateTime(2024, 2),
        end: DateTime(2024, 3),
      ));
    },
  );

  test(
    'previous period delta uses day means, absent if either period is empty',
    () {
      final current = summarizeMood([
        entry(1, .great),
        entry(2, .awful),
        entry(2, .awful),
      ]);
      final previous = summarizeMood([entry(1, .good)]);
      expect(moodPeriodDelta(current, previous), -1);
      expect(moodPeriodDelta(current, summarizeMood([])), isNull);
      expect(moodPeriodDelta(summarizeMood([]), previous), isNull);
    },
  );

  test('empty and unrecorded entries have no average, streak, weekdays or tag deltas', () {
    for (final rows in [
      <MoodInsightEntry>[],
      [entry(1, null)],
    ]) {
      final result = summarizeMood(rows);
      expect(result.average, isNull);
      expect(result.recordedDays, 0);
      expect(result.longestGoodStreak, 0);
      expect(result.distribution.values.every((e) => e == 0), isTrue);
      expect(moodTagDeltas(rows), isEmpty);
      expect(
        moodWeekdayAverages(rows, start: DateTime(2026), end: DateTime(2027)),
        List<double?>.filled(7, null),
      );
    }
  });
}
