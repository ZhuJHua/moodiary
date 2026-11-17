import 'dart:convert';

import 'package:flutter/foundation.dart';

@internal
String formatReminderTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

class Reminder {
  Reminder({
    required this.id,
    required this.hour,
    required this.minute,
    this.endHour,
    this.endMinute,
    required Set<int> weekdays,
    this.enabled = true,
  }) : weekdays = Set.unmodifiable(weekdays) {
    if (id < 1 ||
        id > maxCount ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        weekdays.isEmpty ||
        weekdays.any((day) => day < 1 || day > 7)) {
      throw const FormatException('Invalid reminder');
    }
    if ((endHour == null) != (endMinute == null) ||
        (endHour != null &&
            (endHour! < 0 ||
                endHour! > 23 ||
                endMinute! < 0 ||
                endMinute! > 59 ||
                endHour! * 60 + endMinute! - (hour * 60 + minute) < 30))) {
      throw const FormatException('Invalid reminder window');
    }
  }

  static const maxCount = 5;

  final int id;
  final int hour;
  final int minute;
  final int? endHour;
  final int? endMinute;
  final Set<int> weekdays;
  final bool enabled;

  bool get isRandom => endHour != null;

  String get time => formatReminderTime(hour, minute);

  String get label =>
      isRandom ? '$time–${formatReminderTime(endHour!, endMinute!)}' : time;

  Reminder withEnabled(bool value) => Reminder(
    id: id,
    hour: hour,
    minute: minute,
    endHour: endHour,
    endMinute: endMinute,
    weekdays: weekdays,
    enabled: value,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays.toList()..sort(),
    'enabled': enabled,
    if (isRandom) 'endHour': endHour!,
    if (isRandom) 'endMinute': endMinute!,
  };

  static List<Reminder> decode(String source) {
    try {
      final rows = jsonDecode(source) as List;
      final result = rows
          .map(
            (row) => Reminder(
              id: row['id'] as int,
              hour: row['hour'] as int,
              minute: row['minute'] as int,
              endHour: row['endHour'] as int?,
              endMinute: row['endMinute'] as int?,
              weekdays: (row['weekdays'] as List).cast<int>().toSet(),
              enabled: row['enabled'] as bool,
            ),
          )
          .toList();
      if (result.length > maxCount ||
          result.map((item) => item.id).toSet().length != result.length) {
        return const [];
      }
      return List.unmodifiable(result);
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  static String encode(List<Reminder> reminders) =>
      jsonEncode(reminders.map((reminder) => reminder.toJson()).toList());
}
