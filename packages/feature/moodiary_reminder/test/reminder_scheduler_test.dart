import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';

void main() {
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
    bool skip = true,
    bool written = false,
    TZDateTime? at,
    int salt = 12345,
  }) => ReminderScheduler.desired(
    reminders: reminders ?? [daily],
    enabled: enabled,
    skipIfWritten: skip,
    writtenToday: written,
    now: at ?? now,
    salt: salt,
  );

  test('one weekly slot per enabled weekday and stable ids across ordering and dates', () {
    final other = Reminder(id: 2, hour: 8, minute: 30, weekdays: {1, 5});
    final first = schedule(reminders: [daily, other]);
    final later = schedule(
      reminders: [other, daily],
      at: TZDateTime(UTC, 2026, 11, 18),
    );
    expect(first.length, 9);
    expect(
      first.every((slot) => slot.weekly && ReminderScheduler.ownsId(slot.id)),
      isTrue,
    );
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

  test('skip today swaps today slots for a separate one-shot next week', () {
    final normal = schedule();
    final skipped = schedule(written: true);
    final oneShot = skipped.singleWhere((slot) => !slot.weekly);
    expect(oneShot.at, TZDateTime(UTC, 2026, 11, 23, 21, 30));
    expect(oneShot.id, 200009);
    expect(skipped.any((slot) => slot.id == 100009), isFalse);
    expect(
      skipped.where((slot) => slot.weekly).map((slot) => slot.id).toSet(),
      normal
          .where((slot) => slot.at.weekday != 1)
          .map((slot) => slot.id)
          .toSet(),
    );
    expect(
      schedule(written: true, skip: false).every((slot) => slot.weekly),
      isTrue,
    );
    final restored = schedule(
      written: false,
      at: TZDateTime(UTC, 2026, 11, 17),
    );
    expect(restored.any((slot) => slot.id == 100009), isTrue);
    expect(restored.every((slot) => slot.weekly), isTrue);
  });

  test(
    'written today also swaps past and equal slots to cancel delayed alarms',
    () {
      for (final at in [
        TZDateTime(UTC, 2026, 11, 16, 21, 30),
        TZDateTime(UTC, 2026, 11, 16, 23),
      ]) {
        final monday = schedule(
          written: true,
          at: at,
        ).singleWhere((slot) => slot.at.weekday == 1);
        expect(monday.weekly, isFalse);
        expect(monday.id, 200009);
        expect(monday.at, TZDateTime(UTC, 2026, 11, 23, 21, 30));
        final weekly = schedule(at: at)
            .singleWhere((slot) => slot.at.weekday == 1);
        expect(weekly.weekly, isTrue);
        expect(weekly.id, 100009);
        expect(weekly.at, monday.at);
      }
    },
  );

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

  final window = Reminder(
    id: 1,
    hour: 19,
    minute: 0,
    endHour: 22,
    endMinute: 0,
    weekdays: {1, 3, 5},
  );
  final morning = TZDateTime(UTC, 2026, 11, 16);

  test(
    'random times use stable fastHash and stay within selected days and window',
    () {
      final slots = schedule(reminders: [window], at: morning);
      final repeated = schedule(reminders: [window], at: morning);
      expect(slots.length, 14);
      expect(slots.first.at, TZDateTime(UTC, 2026, 11, 16, 20, 38));
      expect(
        slots.map((slot) => slot.signature),
        repeated.map((slot) => slot.signature),
      );
      expect(slots.map((slot) => slot.id), repeated.map((slot) => slot.id));
      expect(
        schedule(
          reminders: [window],
          at: morning,
          salt: 12346,
        ).map((slot) => slot.signature),
        isNot(slots.map((slot) => slot.signature).toList()),
      );
      for (final slot in slots) {
        expect(slot.weekly, isFalse);
        expect(slot.reminder, same(window));
        expect(window.weekdays, contains(slot.at.weekday));
        expect(
          slot.at.hour * 60 + slot.at.minute,
          inInclusiveRange(19 * 60, 22 * 60),
        );
        final epochDay =
            DateTime.utc(
              slot.at.year,
              slot.at.month,
              slot.at.day,
            ).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
        expect(slot.id, 400000 + window.id * 64 + epochDay % 64);
        expect(ReminderScheduler.ownsId(slot.id), isTrue);
      }
      expect(slots.map((slot) => slot.id).toSet().length, slots.length);
    },
  );

  test(
    'random past or equal times and written-today occurrences are omitted',
    () {
      final first = schedule(reminders: [window], at: morning).first;
      for (final at in [first.at, TZDateTime(UTC, 2026, 11, 16, 23, 59)]) {
        final slots = schedule(reminders: [window], at: at);
        expect(slots.length, 14);
        expect(
          slots.every((slot) => slot.at.isAfter(TZDateTime(UTC, 2026, 11, 17))),
          isTrue,
        );
        expect(slots.any((slot) => slot.id == first.id), isFalse);
      }
      final skipped = schedule(reminders: [window], at: morning, written: true);
      expect(skipped.length, 14);
      expect(skipped.first.at.day, 18);
      expect(
        schedule(
          reminders: [window],
          at: morning,
          written: true,
          skip: false,
        ).first.at,
        first.at,
      );
      expect(schedule(reminders: [window.withEnabled(false)]), isEmpty);
    },
  );

  test(
    'five mixed reminders stay within 60 with the prescribed per-window budget',
    () {
      for (var fixedCount = 0; fixedCount < 5; fixedCount++) {
        final reminders = [
          for (var index = 0; index < 5; index++)
            Reminder(
              id: index + 1,
              hour: 19,
              minute: 0,
              endHour: index < fixedCount ? null : 22,
              endMinute: index < fixedCount ? null : 0,
              weekdays: {1, 2, 3, 4, 5, 6, 7},
            ),
        ];
        final slots = schedule(reminders: reminders, at: morning);
        final randomCount = 5 - fixedCount;
        final budget = ((60 - fixedCount * 7) ~/ randomCount).clamp(0, 14);
        expect(slots.length, fixedCount * 7 + randomCount * budget);
        expect(slots.length, lessThanOrEqualTo(60));
        expect(slots.map((slot) => slot.id).toSet().length, slots.length);
        expect(
          slots.every((slot) => ReminderScheduler.ownsId(slot.id)),
          isTrue,
        );
        for (final reminder in reminders.where(
          (reminder) => reminder.isRandom,
        )) {
          expect(
            slots.where((slot) => slot.reminder.id == reminder.id).length,
            budget,
          );
        }
      }
      expect(ReminderScheduler.ownsId(400063), isFalse);
      expect(ReminderScheduler.ownsId(400384), isFalse);
    },
  );

  test('sparse random weekdays keep unique ids through the 64-day wrap', () {
    final slots = schedule(
      reminders: [
        Reminder(
          id: 5,
          hour: 19,
          minute: 0,
          endHour: 22,
          endMinute: 0,
          weekdays: {1},
        ),
      ],
      at: morning,
    );
    expect(slots.length, 14);
    expect(slots.last.at.difference(slots.first.at).inDays, greaterThan(64));
    expect(slots.map((slot) => slot.id).toSet().length, 14);
  });

  test(
    'random signatures include exact times and next labels show the window',
    () async {
      final first = schedule(reminders: [window], at: morning).first;
      final moved = schedule(
        reminders: [
          Reminder(
            id: 1,
            hour: 20,
            minute: 0,
            endHour: 23,
            endMinute: 0,
            weekdays: window.weekdays,
          ),
        ],
        at: morning,
      ).first;
      expect(first.id, moved.id);
      expect(first.signature, isNot(moved.signature));
      await LocaleSettings.setLocale(AppLocale.zh);
      expect(nextReminderLabel(l10n, first, morning), '下次 今天 19:00–22:00');
      final sunday = TZDateTime(UTC, 2026, 11, 15);
      expect(
        nextReminderLabel(
          l10n,
          schedule(reminders: [window], at: sunday).firstOrNull,
          sunday,
        ),
        '下次 明天 19:00–22:00',
      );
    },
  );
}
