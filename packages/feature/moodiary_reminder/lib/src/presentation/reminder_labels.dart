import 'package:flutter/foundation.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

import '../application/reminder_service.dart';
import '../data/reminder.dart';

enum ReminderPreset {
  everyDay,
  workdays,
  weekend,
  custom;

  static ReminderPreset of(Set<int> days) => values.firstWhere(
    (preset) => setEquals(preset.days, days),
    orElse: () => custom,
  );

  Set<int> get days => switch (this) {
    everyDay => {1, 2, 3, 4, 5, 6, 7},
    workdays => {1, 2, 3, 4, 5},
    weekend => {6, 7},
    custom => {},
  };
}

String reminderDaysLabel(Translations l10n, Set<int> days) {
  switch (ReminderPreset.of(days)) {
    case ReminderPreset.everyDay:
      return l10n.reminder.everyDay;
    case ReminderPreset.workdays:
      return l10n.reminder.workdays;
    case ReminderPreset.weekend:
      return l10n.reminder.weekend;
    case ReminderPreset.custom:
      final ordered = days.toList()..sort();
      return ordered
          .map((day) => l10n.reminder.weekdays[day - 1])
          .join(l10n.reminder.daySeparator);
  }
}

String reminderStatusLabel(Translations l10n, ReminderState service) =>
    service.reminders.isEmpty
    ? l10n.reminder.addFirst
    : !service.enabled
    ? l10n.reminder.off
    : nextReminderLabel(l10n, service.next, service.now);

String nextReminderLabel(Translations l10n, DateTime? at, DateTime now) {
  if (at == null) return l10n.reminder.noEnabledTimes;
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
  return l10n.reminder.next(
    day: day,
    time: formatReminderTime(at.hour, at.minute),
  );
}
