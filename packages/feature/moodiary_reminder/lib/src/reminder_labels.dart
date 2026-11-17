import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_platform/moodiary_platform.dart';

import 'reminder_scheduler.dart';

enum ReminderPreset {
  everyDay,
  workdays,
  weekend,
  custom;

  Set<int> get days => switch (this) {
    everyDay => {1, 2, 3, 4, 5, 6, 7},
    workdays => {1, 2, 3, 4, 5},
    weekend => {6, 7},
    custom => {},
  };
}

String reminderDaysLabel(Translations l10n, Set<int> days) {
  for (final preset in ReminderPreset.values) {
    if (preset != ReminderPreset.custom &&
        days.length == preset.days.length &&
        days.containsAll(preset.days)) {
      return switch (preset) {
        ReminderPreset.everyDay => l10n.reminder.everyDay,
        ReminderPreset.workdays => l10n.reminder.workdays,
        ReminderPreset.weekend => l10n.reminder.weekend,
        ReminderPreset.custom => l10n.common.custom,
      };
    }
  }
  final ordered = days.toList()..sort();
  return ordered
      .map((day) => l10n.reminder.weekdays[day - 1])
      .join(l10n.reminder.daySeparator);
}

String nextReminderLabel(
  Translations l10n,
  ReminderNotification? next,
  TZDateTime now,
) {
  if (next == null) return l10n.reminder.noEnabledTimes;
  final at = next.at;
  final days = DateTime.utc(
    at.year,
    at.month,
    at.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  final day = switch (days) {
    0 => l10n.reminder.today,
    1 => l10n.reminder.tomorrow,
    _ => l10n.reminder.weekdays[at.weekday - 1],
  };
  return l10n.reminder.next(day: day, time: next.reminder.label);
}
