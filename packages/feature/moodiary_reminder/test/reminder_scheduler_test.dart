import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_platform/testing.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';

void main() {
  setUpAll(initializeTimeZones);

  final now = TZDateTime(UTC, 2026, 11, 16, 20);
  final daily = Reminder(
    id: 1,
    hour: 21,
    minute: 30,
    weekdays: {1, 2, 3, 4, 5, 6, 7},
  );
  List<ReminderNotification> schedule({
    List<Reminder>? reminders,
    bool enabled = true,
    TZDateTime? at,
  }) => ReminderScheduler.desired(
    reminders: reminders ?? [daily],
    enabled: enabled,
    now: at ?? now,
  );

  test('one weekly slot per enabled weekday and stable ids across ordering and dates', () {
    final other = Reminder(id: 2, hour: 8, minute: 30, weekdays: {1, 5});
    final first = schedule(reminders: [daily, other]);
    final later = schedule(
      reminders: [other, daily],
      at: TZDateTime(UTC, 2026, 11, 18),
    );
    expect(first.length, 9);
    expect(first.every((slot) => ReminderScheduler.ownsId(slot.id)), isTrue);
    expect(
      first.map((slot) => slot.id).toSet(),
      later.map((slot) => slot.id).toSet(),
    );
    expect(first.map((slot) => slot.id).toSet().length, first.length);
    expect(first.first.at, TZDateTime(UTC, 2026, 11, 16, 21, 30));
  });

  test('master and individual switches disable slots', () {
    expect(schedule(enabled: false), isEmpty);
    expect(schedule(reminders: [daily.withEnabled(false)]), isEmpty);
  });

  test('DST gaps preserve the configured weekly wall time in the template', () {
    final location = getLocation('America/New_York');
    final reminders = [
      Reminder(id: 1, hour: 2, minute: 30, weekdays: {7}),
    ];
    final gap = schedule(
      reminders: reminders,
      at: TZDateTime(location, 2027, 3, 10, 12),
    ).single;
    expect(gap.at, TZDateTime(location, 2027, 3, 14, 3, 30));
    expect(gap.template, TZDateTime(location, 2027, 3, 7, 2, 30));
    expect(gap.signature, 'America/New_York:7:2:30');
    for (final day in [3, 17]) {
      final normal = schedule(
        reminders: reminders,
        at: TZDateTime(location, 2027, 3, day, 12),
      ).single;
      expect(normal.template, same(normal.at));
      expect(normal.at, TZDateTime(location, 2027, 3, day + 4, 2, 30));
      expect(normal.signature, gap.signature);
    }
  });

  test('past and equal slots advance one week with the same weekly id', () {
    for (final at in [
      TZDateTime(UTC, 2026, 11, 16, 21, 30),
      TZDateTime(UTC, 2026, 11, 16, 23),
    ]) {
      final monday = schedule(at: at)
          .singleWhere((slot) => slot.at.weekday == 1);
      expect(monday.id, 100009);
      expect(monday.at, TZDateTime(UTC, 2026, 11, 23, 21, 30));
      expect(monday.signature, schedule().first.signature);
    }
  });

  test('five daily reminders have unique owned weekly ids only', () {
    final slots = schedule(
      reminders: [
        for (var id = 1; id <= Reminder.maxCount; id++)
          Reminder(id: id, hour: 8, minute: 30, weekdays: daily.weekdays),
      ],
    );
    expect(slots.length, 35);
    expect(slots.map((slot) => slot.id).toSet().length, 35);
    for (final slot in slots) {
      expect(slot.id, 100000 + slot.reminder.id * 8 + slot.at.weekday);
      expect(ReminderScheduler.ownsId(slot.id), isTrue);
    }
    expect(ReminderScheduler.ownsId(100009), isTrue);
    expect(ReminderScheduler.ownsId(100047), isTrue);
    for (final id in [100007, 100048, 200009, 400064, 300000]) {
      expect(ReminderScheduler.ownsId(id), isFalse);
    }
  });

  test('next labels cover today, tomorrow, weekday and Sunday wrap', () async {
    await LocaleSettings.setLocale(AppLocale.zh);
    expect(nextReminderLabel(l10n, schedule().firstOrNull, now), '下次 今天 21:30');
    final after = TZDateTime(UTC, 2026, 11, 16, 22);
    expect(
      nextReminderLabel(l10n, schedule(at: after).firstOrNull, after),
      '下次 明天 21:30',
    );
    final friday = schedule(
      reminders: [
        Reminder(id: 2, hour: 8, minute: 30, weekdays: {5}),
      ],
    );
    expect(nextReminderLabel(l10n, friday.firstOrNull, now), '下次 周五 08:30');
    final sunday = TZDateTime(UTC, 2026, 11, 22, 22);
    final monday = schedule(
      reminders: [
        Reminder(id: 2, hour: 8, minute: 30, weekdays: {1}),
      ],
      at: sunday,
    );
    expect(nextReminderLabel(l10n, monday.firstOrNull, sunday), '下次 明天 08:30');
  });
}
