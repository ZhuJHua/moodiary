import 'package:moodiary_diary/src/application/diary_stamp.dart';
import 'package:moodiary_models/moodiary_models.dart';

export 'package:moodiary_diary/src/application/diary_stamp.dart'
    show diaryStampOf;

class TimelineEntry {
  final Diary diary;

  final DateTime stamp;

  final bool dayStart;

  final bool breakBefore;

  const TimelineEntry({
    required this.diary,
    required this.stamp,
    required this.dayStart,
    required this.breakBefore,
  });
}

class TimelineMonth {
  final DateTime month;
  final List<TimelineEntry> entries;

  const TimelineMonth({required this.month, required this.entries});
}

List<TimelineMonth> buildTimeline(List<Diary> diaries, DiarySort sort) {
  final months = <TimelineMonth>[];
  var entries = <TimelineEntry>[];
  DateTime? currentMonth;
  DateTime? prevDay;

  for (final diary in diaries) {
    final stamp = diaryStampOf(diary, sort);
    // 日键须用 UTC 构造：本地零点在夏令时切换日会导致 Duration.inDays 漏判断档
    final day = DateTime.utc(stamp.year, stamp.month, stamp.day);
    final month = DateTime(stamp.year, stamp.month);

    if (currentMonth == null || month != currentMonth) {
      if (currentMonth != null) {
        months.add(TimelineMonth(month: currentMonth, entries: entries));
        entries = <TimelineEntry>[];
      }
      currentMonth = month;
    }

    entries.add(
      TimelineEntry(
        diary: diary,
        stamp: stamp,
        dayStart: prevDay == null || day != prevDay,
        breakBefore:
            prevDay != null && day.difference(prevDay).inDays.abs() > 1,
      ),
    );
    prevDay = day;
  }

  if (currentMonth != null) {
    months.add(TimelineMonth(month: currentMonth, entries: entries));
  }
  return months;
}
