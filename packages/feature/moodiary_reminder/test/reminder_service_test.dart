import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart' show AppLifecycleState, VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

class _Permission extends Fake implements NotificationPermission {
  bool enabled = true;

  @override
  Future<bool> isEnabled() async => enabled;
}

class _Notifications implements ReminderNotifications {
  final schedules = <ReminderSchedule>[];
  bool channelEnabled = true;
  int channelChecks = 0;
  final launch = Completer<bool>();
  VoidCallback? handler;
  (String, String, String)? testContent;
  Completer<void>? scheduleGate;

  @override
  void setTapHandler(VoidCallback? handler) => this.handler = handler;

  @override
  Future<bool> consumeLaunchTap() {
    expect(handler, isNotNull);
    return launch.future;
  }

  @override
  Future<void> setSchedule(ReminderSchedule schedule) async {
    schedules.add(schedule);
    await scheduleGate?.future;
  }

  @override
  Future<void> showTest(String title, String body, String channelName) async {
    testContent = (title, body, channelName);
  }

  @override
  Future<bool> isChannelEnabled() async {
    channelChecks++;
    return channelEnabled;
  }
}

class _Service extends ReminderService {
  _Service(super.notifications, super.permission);

  @override
  DateTime now = DateTime(2026, 11, 16, 20);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _Notifications notifications;
  late _Permission permission;
  late _Service service;
  late ProviderContainer container;
  final morning = Reminder(id: 1, hour: 8, minute: 5, weekdays: {5, 1});
  final evening = Reminder(id: 2, hour: 21, minute: 30, weekdays: {1, 2});

  Future<void> initialize() async {
    notifications.launch.complete(false);
    await service.initialize();
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    await LocaleSettings.setLocale(AppLocale.zh);
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
    MoodiaryKVs.reminders.set(Reminder.encode([morning, evening]));
    MoodiaryKVs.reminderEnabled.set(true);
    notifications = _Notifications();
    permission = _Permission();
    service = _Service(notifications, permission);
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [reminderServiceProvider.overrideWithValue(service)],
    );
    addTearDown(() async {
      await service.dispose();
      expect(notifications.handler, isNull);
      await LocaleSettings.setLocale(AppLocale.zh);
    });
  });

  test(
    'initialization sends one localized slot per enabled reminder',
    () async {
      await initialize();
      final schedule = notifications.schedules.single;
      expect(schedule.channelName, l10n.reminder.channelName);
      expect(schedule.slots.map((slot) => slot.id), [1, 2]);
      final first = schedule.slots.first;
      expect((first.hour, first.minute), (8, 5));
      expect(first.weekdays, [1, 5]);
      expect((first.title, first.body), ('早上好', '写下今早的心情。'));
      expect(schedule.slots.last.title, '晚上好');

      await service.save(morning.withEnabled(false));
      expect(notifications.schedules.last.slots.map((slot) => slot.id), [2]);
      await service.setEnabled(false);
      expect(notifications.schedules.last.slots, isEmpty);
      await service.setEnabled(true);
      expect(notifications.schedules.last.slots.single.id, 2);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(notifications.schedules, hasLength(4));
    },
  );

  test(
    'external KV edits coalesce and locale changes re-send the copy',
    () async {
      await initialize();
      MoodiaryKVs.reminderEnabled.set(false);
      MoodiaryKVs.reminders.set(Reminder.encode([morning]));
      MoodiaryKVs.reminderEnabled.set(true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(notifications.schedules, hasLength(2));
      expect(notifications.schedules.last.slots.single.id, 1);
      await LocaleSettings.setLocale(AppLocale.en);
      await Future<void>.delayed(Duration.zero);
      final schedule = notifications.schedules.last;
      expect(notifications.schedules, hasLength(3));
      expect(schedule.channelName, l10n.reminder.channelName);
      final slot = schedule.slots.single;
      expect(
        (slot.title, slot.body),
        ('Good morning', 'Write how you feel this morning.'),
      );
    },
  );

  test('a queued edit survives a failed native write', () async {
    await initialize();
    final gate = notifications.scheduleGate = Completer<void>();
    final failed = expectLater(service.setEnabled(false), throwsStateError);
    await Future<void>.delayed(Duration.zero);
    final following = service.setEnabled(true);
    expect(notifications.schedules.last.slots, isEmpty);
    notifications.scheduleGate = null;
    gate.completeError(StateError('schedule failed'));
    await failed;
    await following;
    expect(notifications.schedules, hasLength(3));
    expect(notifications.schedules.last.slots, hasLength(2));
  });

  for (final buffered in [false, true]) {
    test('tap handoff preserves live taps with buffered=$buffered', () async {
      var taps = 0;
      final subscription = service.taps.listen((_) => taps++);
      addTearDown(subscription.cancel);
      final initializing = service.initialize();
      if (!buffered) notifications.handler!();
      notifications.launch.complete(buffered);
      await initializing;
      await Future<void>.delayed(Duration.zero);
      expect(service.launchedFromNotification, isTrue);
      expect(taps, 1);
      expect(service.consumeTap(), isTrue);
      notifications.handler!();
      await Future<void>.delayed(Duration.zero);
      expect(service.launchedFromNotification, isTrue);
      expect(taps, 2);
    });
  }

  test('test notification uses the current local hour', () async {
    service.now = DateTime(2026, 11, 16, 13, 59);
    await service.sendTest();
    expect(notifications.testContent, (
      '午间片刻',
      '记一件上午的小事。',
      l10n.reminder.channelName,
    ));
    expect(notifications.schedules, isEmpty);
  });

  test('resume reapplies the schedule after permission returns', () async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    permission.enabled = false;
    expect(await service.checkPermission(), isFalse);
    final gate = notifications.scheduleGate = Completer<void>();
    await initialize();
    final original = notifications.schedules.single;
    gate.completeError(StateError('permission denied'));
    await Future<void>.delayed(Duration.zero);
    notifications.scheduleGate = null;
    permission.enabled = true;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(service.notificationsEnabled, isTrue);
    expect(notifications.schedules, [original, original]);
    notifications.channelEnabled = false;
    expect(await service.checkPermission(), isFalse);
    notifications.channelEnabled = true;
    permission.enabled = false;
    final checks = notifications.channelChecks;
    expect(await service.checkPermission(), isFalse);
    expect(notifications.channelChecks, checks);
    permission.enabled = true;
    expect(await service.checkPermission(), isTrue);
  });

  test('tap action persists without changing the schedule', () {
    expect(service.tapAction, ReminderTapAction.openApp);
    service.setTapAction(ReminderTapAction.newDiary);
    expect(MoodiaryKVs.reminderTapAction.get(), 'newDiary');
    expect(service.tapAction, ReminderTapAction.newDiary);
    expect(notifications.schedules, isEmpty);
  });

  test('next label follows the clock, selected days and switches', () async {
    final strings = AppLocale.en.translations;
    await initialize();
    expect(service.next, DateTime(2026, 11, 16, 21, 30));
    expect(
      reminderStatusLabel(strings, container.read(reminderStateProvider)),
      strings.reminder.next(day: strings.reminder.today, time: '21:30'),
    );
    service.now = service.next!;
    container.invalidate(reminderStateProvider);
    expect(service.next, DateTime(2026, 11, 17, 21, 30));
    expect(
      reminderStatusLabel(strings, container.read(reminderStateProvider)),
      strings.reminder.next(day: strings.reminder.tomorrow, time: '21:30'),
    );
    await service.remove(2);
    expect(service.next, DateTime(2026, 11, 20, 8, 5));
    expect(
      reminderStatusLabel(strings, container.read(reminderStateProvider)),
      strings.reminder.next(day: strings.reminder.weekdays[4], time: '08:05'),
    );
    await service.setEnabled(false);
    expect(service.next, isNull);
    expect(
      reminderStatusLabel(strings, container.read(reminderStateProvider)),
      strings.reminder.off,
    );
    await service.save(morning.withEnabled(false));
    await service.setEnabled(true);
    expect(
      reminderStatusLabel(strings, container.read(reminderStateProvider)),
      strings.reminder.noEnabledTimes,
    );
    await service.remove(1);
    expect(
      reminderStatusLabel(strings, container.read(reminderStateProvider)),
      strings.reminder.addFirst,
    );
    expect(service.enabled, isFalse);
  });

  test(
    'New York gap shifts forward and overlap uses the earlier instant',
    () async {
      await initialize();
      await service.remove(2);
      await service.save(Reminder(id: 1, hour: 2, minute: 30, weekdays: {7}));
      service.now = DateTime(2027, 3, 14);
      expect(service.next, DateTime(2027, 3, 14, 3, 30));
      await service.save(Reminder(id: 1, hour: 1, minute: 30, weekdays: {7}));
      service.now = DateTime(2027, 11, 7);
      expect(service.next!.toUtc(), DateTime.utc(2027, 11, 7, 5, 30));
      service.now = DateTime.utc(2027, 11, 7, 5, 45).toLocal();
      expect(service.next, DateTime(2027, 11, 14, 1, 30));
    },
    skip: Platform.environment['TZ'] != 'America/New_York',
  );

  test('Nuuk sees a Saturday reminder shifted into Sunday', () async {
    await initialize();
    await service.remove(2);
    await service.save(Reminder(id: 1, hour: 23, minute: 30, weekdays: {6}));
    service.now = DateTime(2027, 3, 28, 0, 10);
    expect(service.next, DateTime(2027, 3, 28, 0, 30));
  }, skip: Platform.environment['TZ'] != 'America/Nuuk');
}
