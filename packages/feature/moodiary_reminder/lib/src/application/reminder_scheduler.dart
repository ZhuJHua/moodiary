import 'dart:math';

import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../data/reminder.dart';

const _fixedWeeklyBase = 100000;
const _fixedSkipBase = 200000;
const _randomBase = 400000;

class ReminderNotification {
  const ReminderNotification({
    required this.id,
    required this.at,
    required this.weekly,
    required this.reminder,
  });

  final int id;
  final TZDateTime at;
  final bool weekly;
  final Reminder reminder;

  String get signature => weekly
      ? '${at.location.name}:${at.weekday}:${at.hour}:${at.minute}'
      : '${at.location.name}:${at.millisecondsSinceEpoch}';
}

abstract final class ReminderScheduler {
  static bool ownsId(int id) {
    bool inRange(int base, int stride) =>
        id >= base + stride && id < base + (Reminder.maxCount + 1) * stride;
    return inRange(_fixedWeeklyBase, 8) ||
        inRange(_fixedSkipBase, 8) ||
        inRange(_randomBase, 64);
  }

  static List<ReminderNotification> desired({
    required List<Reminder> reminders,
    required bool enabled,
    required bool skipIfWritten,
    required bool writtenToday,
    required TZDateTime now,
    required int salt,
  }) {
    if (!enabled) return const [];
    final result = <ReminderNotification>[];
    final active = reminders.where((reminder) => reminder.enabled).toList();
    for (final reminder in active.where((reminder) => !reminder.isRandom)) {
      for (final day in reminder.weekdays) {
        final offset = (day - now.weekday + 7) % 7;
        var at = TZDateTime(
          now.location,
          now.year,
          now.month,
          now.day + offset,
          reminder.hour,
          reminder.minute,
        );
        final skip = offset == 0 && skipIfWritten && writtenToday;
        if (!at.isAfter(now) || skip) {
          at = TZDateTime(
            now.location,
            at.year,
            at.month,
            at.day + 7,
            reminder.hour,
            reminder.minute,
          );
        }
        result.add(
          ReminderNotification(
            id:
                (skip ? _fixedSkipBase : _fixedWeeklyBase) +
                reminder.id * 8 +
                day,
            at: at,
            weekly: !skip,
            reminder: reminder,
          ),
        );
      }
    }
    final random = active.where((reminder) => reminder.isRandom).toList();
    final count = random.isEmpty
        ? 0
        : min(
            14,
            (LocalNotifications.maxPending - result.length) ~/ random.length,
          );
    for (final reminder in random) {
      final start = reminder.hour * 60 + reminder.minute;
      final window = reminder.endHour! * 60 + reminder.endMinute! - start;
      var added = 0;
      for (var offset = 0; added < count; offset++) {
        final date = DateTime.utc(now.year, now.month, now.day + offset);
        if (!reminder.weekdays.contains(date.weekday)) continue;
        if (offset == 0 && skipIfWritten && writtenToday) continue;
        final hash = fastHash(
          '$salt:${reminder.id}:${date.year}-${date.month}-${date.day}',
        );
        final minute = start + hash % (window + 1);
        final at = TZDateTime(
          now.location,
          date.year,
          date.month,
          date.day,
          minute ~/ 60,
          minute % 60,
        );
        if (!at.isAfter(now)) continue;
        final epochDay =
            date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
        result.add(
          ReminderNotification(
            id: _randomBase + reminder.id * 64 + epochDay % 64,
            at: at,
            weekly: false,
            reminder: reminder,
          ),
        );
        added++;
      }
    }
    result.sort((first, second) {
      final order = first.at.compareTo(second.at);
      return order == 0 ? first.id.compareTo(second.id) : order;
    });
    return result;
  }
}
