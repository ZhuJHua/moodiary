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
  }

  static const maxCount = 5;

  final int id;
  final int hour;
  final int minute;
  final Set<int> weekdays;
  final bool enabled;

  String get time => formatReminderTime(hour, minute);

  Reminder withEnabled(bool value) => Reminder(
    id: id,
    hour: hour,
    minute: minute,
    weekdays: weekdays,
    enabled: value,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays.toList()..sort(),
    'enabled': enabled,
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
