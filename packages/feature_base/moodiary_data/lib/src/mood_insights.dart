import 'package:moodiary_models/moodiary_models.dart';

/// A lightweight projection; rich content and media are loaded only on demand.
class MoodInsightEntry {
  final String id;
  final DateTime time;
  final DiaryMood? mood;
  final String title;
  final String preview;
  final List<String> tags;

  const MoodInsightEntry({
    required this.id,
    required this.time,
    this.mood,
    this.title = '',
    this.preview = '',
    this.tags = const [],
  });
}

DateTime moodDayKey(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Calendar arithmetic deliberately avoids 24-hour durations across DST changes.
DateTime moodDayOffset(DateTime day, int offset) =>
    DateTime(day.year, day.month, day.day + offset);

enum MoodInsightsScope { week, month, year }

/// Half-open local-time bounds. Weeks always begin on Sunday.
({DateTime start, DateTime end}) moodPeriodBounds(
  DateTime anchor,
  MoodInsightsScope scope,
) {
  final day = moodDayKey(anchor);
  return switch (scope) {
    .week => (
      start: moodDayOffset(day, -(day.weekday % 7)),
      end: moodDayOffset(day, 7 - day.weekday % 7),
    ),
    .month => (
      start: DateTime(day.year, day.month),
      end: DateTime(day.year, day.month + 1),
    ),
    .year => (start: DateTime(day.year), end: DateTime(day.year + 1)),
  };
}

DiaryMood? moodLevel(double? average) =>
    average == null ? null : DiaryMood.fromScore(average.round());

double? _mean(Iterable<num> values) {
  var sum = 0.0;
  var count = 0;
  for (final value in values) {
    sum += value;
    count++;
  }
  return count == 0 ? null : sum / count;
}

class MoodInsightDay {
  final List<MoodInsightEntry> entries;
  final double? average;
  DiaryMood? get level => moodLevel(average);

  MoodInsightDay(this.entries)
    : average = _mean(entries.map((e) => e.mood?.score).nonNulls);
}

Map<DateTime, MoodInsightDay> moodDays(Iterable<MoodInsightEntry> entries) {
  final grouped = <DateTime, List<MoodInsightEntry>>{};
  for (final entry in entries) {
    (grouped[moodDayKey(entry.time)] ??= []).add(entry);
  }
  return {for (final e in grouped.entries) e.key: MoodInsightDay(e.value)};
}

/// Calendar-month means of recorded day means, keyed by local month start.
/// Unrecorded-only months are present with a null average.
Map<DateTime, double?> moodMonthAverages(Iterable<MoodInsightEntry> entries) =>
    _moodPeriodAverages(entries, (day) => DateTime(day.year, day.month));

/// Calendar-year means of recorded day means (not means of month means).
Map<DateTime, double?> moodYearAverages(Iterable<MoodInsightEntry> entries) =>
    _moodPeriodAverages(entries, (day) => DateTime(day.year));

Map<DateTime, double?> _moodPeriodAverages(
  Iterable<MoodInsightEntry> entries,
  DateTime Function(DateTime) periodKey,
) {
  final periods = <DateTime, List<double>>{};
  for (final day in moodDays(entries).entries) {
    final values = periods.putIfAbsent(periodKey(day.key), () => []);
    if (day.value.average case final average?) values.add(average);
  }
  return {
    for (final period in periods.entries) period.key: _mean(period.value),
  };
}

class MoodInsightsSummary {
  final Map<DateTime, MoodInsightDay> days;
  final double? average;
  final int entryCount;
  final int recordedDays;
  final int longestGoodStreak;
  final Map<DiaryMood, int> distribution;

  const MoodInsightsSummary({
    required this.days,
    required this.average,
    required this.entryCount,
    required this.recordedDays,
    required this.longestGoodStreak,
    required this.distribution,
  });
}

MoodInsightsSummary summarizeMood(Iterable<MoodInsightEntry> entries) {
  final rows = entries.toList();
  final days = moodDays(rows);
  final recorded = days.entries.where((e) => e.value.average != null).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  var longest = 0;
  var streak = 0;
  DateTime? previous;
  for (final day in recorded) {
    if (day.value.average!.round() >= DiaryMood.good.score) {
      streak = previous != null && moodDayOffset(previous, 1) == day.key
          ? streak + 1
          : 1;
      if (streak > longest) longest = streak;
      previous = day.key;
    } else {
      streak = 0;
      previous = null;
    }
  }
  return MoodInsightsSummary(
    days: days,
    average: _mean(recorded.map((e) => e.value.average!)),
    entryCount: rows.length,
    recordedDays: recorded.length,
    longestGoodStreak: longest,
    distribution: {
      for (final mood in DiaryMood.values)
        mood: rows.where((e) => e.mood == mood).length,
    },
  );
}

/// Sunday first. Each weekday weighs its recorded days equally.
List<double?> moodWeekdayAverages(
  Iterable<MoodInsightEntry> entries, {
  required DateTime start,
  required DateTime end,
}) {
  final days = moodDays(
    entries.where(
      (e) =>
          !moodDayKey(e.time).isBefore(start) &&
          moodDayKey(e.time).isBefore(end),
    ),
  );
  return [
    for (var weekday = 0; weekday < 7; weekday++)
      _mean(
        days.entries
            .where((e) => e.key.weekday % 7 == weekday)
            .map((e) => e.value.average)
            .nonNulls,
      ),
  ];
}

class MoodTagDelta {
  final String tag;
  final int count;
  final double delta;
  const MoodTagDelta(this.tag, this.count, this.delta);
}

List<MoodTagDelta> moodTagDeltas(Iterable<MoodInsightEntry> entries) {
  final recorded = entries.where((e) => e.mood != null).toList();
  final overall = _mean(recorded.map((e) => e.mood!.score));
  if (overall == null) return const [];
  final tags = <String, List<int>>{};
  for (final entry in recorded) {
    for (final tag in entry.tags.toSet()) {
      (tags[tag] ??= []).add(entry.mood!.score);
    }
  }
  final deltas =
      [
        for (final tag in tags.entries)
          if (tag.value.length >= 5)
            MoodTagDelta(
              tag.key,
              tag.value.length,
              _mean(tag.value)! - overall,
            ),
      ]..sort((a, b) {
        final magnitude = b.delta.abs().compareTo(a.delta.abs());
        return magnitude == 0 ? a.tag.compareTo(b.tag) : magnitude;
      });
  return deltas.take(7).toList();
}

double? moodPeriodDelta(
  MoodInsightsSummary current,
  MoodInsightsSummary previous,
) => current.average == null || previous.average == null
    ? null
    : current.average! - previous.average!;
