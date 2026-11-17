import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';

void main() {
  test('fixed reminders round trip and preserve fields on enabled changes', () {
    final reminder = Reminder(id: 1, hour: 8, minute: 5, weekdays: {1, 3, 5});
    final decoded = Reminder.decode(Reminder.encode([reminder])).single;
    expect(decoded.toJson(), reminder.toJson());
    expect(decoded.time, '08:05');
    expect(decoded.withEnabled(false).toJson(), {
      ...reminder.toJson(),
      'enabled': false,
    });
  });

  test('fixed reminders without window fields decode and keep that format', () {
    final reminder = Reminder.decode(
      '[{"id":1,"hour":8,"minute":30,"weekdays":[1,2],"enabled":true}]',
    ).single;
    expect(reminder.time, '08:30');
    expect(reminder.toJson(), {
      'id': 1,
      'hour': 8,
      'minute': 30,
      'weekdays': [1, 2],
      'enabled': true,
    });
  });

  test('legacy window fields are ignored and keep the fixed start time', () {
    final reminder = Reminder.decode(
      '[{"id":1,"hour":19,"minute":15,"endHour":22,"endMinute":45,"weekdays":[1,3],"enabled":false}]',
    ).single;
    expect(reminder.time, '19:15');
    expect(reminder.toJson(), {
      'id': 1,
      'hour': 19,
      'minute': 15,
      'weekdays': [1, 3],
      'enabled': false,
    });
  });
}
