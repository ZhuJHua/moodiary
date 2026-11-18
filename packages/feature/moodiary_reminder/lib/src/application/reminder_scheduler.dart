import 'package:moodiary_platform/moodiary_platform.dart';

import '../data/reminder.dart';

const _fixedWeeklyBase = 100000;

class ReminderNotification {
  const ReminderNotification({
    required this.id,
    required this.at,
    required this.template,
    required this.reminder,
  });

  final int id;
  final TZDateTime at;
  final TZDateTime template;
  final Reminder reminder;

  String get signature =>
      '${template.location.name}:${template.weekday}:${template.hour}:${template.minute}';
}

abstract final class ReminderScheduler {
  static bool ownsId(int id) =>
      id >= _fixedWeeklyBase + 8 &&
      id < _fixedWeeklyBase + (Reminder.maxCount + 1) * 8;

  static List<ReminderNotification> desired({
    required List<Reminder> reminders,
    required bool enabled,
    required TZDateTime now,
  }) {
    if (!enabled) return const [];
    final result = <ReminderNotification>[];
    for (final reminder in reminders.where((reminder) => reminder.enabled)) {
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
        if (!at.isAfter(now)) {
          at = TZDateTime(
            now.location,
            at.year,
            at.month,
            at.day + 7,
            reminder.hour,
            reminder.minute,
          );
        }
        final template =
            at.hour == reminder.hour && at.minute == reminder.minute
            ? at
            : TZDateTime(
                at.location,
                at.year,
                at.month,
                at.day - 7,
                reminder.hour,
                reminder.minute,
              );
        result.add(
          ReminderNotification(
            id: _fixedWeeklyBase + reminder.id * 8 + day,
            at: at,
            template: template,
            reminder: reminder,
          ),
        );
      }
    }
    result.sort((first, second) {
      final order = first.at.compareTo(second.at);
      return order == 0 ? first.id.compareTo(second.id) : order;
    });
    return result;
  }
}
