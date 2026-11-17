import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';

void main() {
  test('random windows round trip and survive enabled changes', () {
    final reminder = Reminder(
      id: 1,
      hour: 19,
      minute: 0,
      endHour: 22,
      endMinute: 0,
      weekdays: {1, 3, 5},
    );
    final decoded = Reminder.decode(Reminder.encode([reminder])).single;
    expect(decoded.toJson(), reminder.toJson());
    expect(decoded.isRandom, isTrue);
    expect(decoded.time, '19:00');
    expect(decoded.label, '19:00–22:00');
    expect(decoded.withEnabled(false).label, reminder.label);
    expect(decoded.withEnabled(false).endHour, 22);
    expect(decoded.withEnabled(false).endMinute, 0);
    expect(decoded.withEnabled(false).enabled, isFalse);
  });

  test('fixed reminders without window fields decode and keep that format', () {
    final reminder = Reminder.decode(
      '[{"id":1,"hour":8,"minute":30,"weekdays":[1,2],"enabled":true}]',
    ).single;
    expect(reminder.isRandom, isFalse);
    expect(reminder.label, '08:30');
    expect(reminder.endHour, isNull);
    expect(reminder.endMinute, isNull);
    expect(reminder.toJson().containsKey('endHour'), isFalse);
    expect(reminder.toJson().containsKey('endMinute'), isFalse);
  });

  test('windows reject incomplete, short, reversed and out-of-day ends', () {
    for (final (endHour, endMinute) in <(int?, int?)>[
      (null, 30),
      (22, null),
      (19, 29),
      (18, 59),
      (24, 0),
      (22, 60),
      (-1, 0),
      (22, -1),
    ]) {
      expect(
        () => Reminder(
          id: 1,
          hour: 19,
          minute: 0,
          endHour: endHour,
          endMinute: endMinute,
          weekdays: {1},
        ),
        throwsFormatException,
      );
    }
    expect(
      Reminder(
        id: 1,
        hour: 23,
        minute: 29,
        endHour: 23,
        endMinute: 59,
        weekdays: {1},
      ).label,
      '23:29–23:59',
    );
    expect(
      Reminder.decode(
        '[{"id":1,"hour":19,"minute":0,"endHour":22,"weekdays":[1],"enabled":true}]',
      ),
      isEmpty,
    );
  });
}
