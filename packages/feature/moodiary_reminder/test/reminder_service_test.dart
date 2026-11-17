import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

class _Permission implements NotificationPermission {
  bool enabled = true;
  int requests = 0;
  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<bool> request() async {
    requests++;
    return enabled;
  }

  @override
  Future<void> openSettings() async {}
}

class _Diaries extends Fake implements DiaryRepository {
  bool written = false;
  int reads = 0;
  final events = StreamController<DiaryEvent>.broadcast();
  @override
  Stream<DiaryEvent> get diaryEvents => events.stream;
  @override
  Future<bool> hasDiaryOnDate(DateTime date) async {
    reads++;
    return written;
  }
}

class _Notifications extends Fake implements LocalNotifications {
  TZDateTime current = TZDateTime(UTC, 2026, 11, 16, 20);
  String zone = 'UTC';
  bool channelEnabled = true;
  bool launch = false;
  bool failNext = false;
  int scheduled = 0;
  int zoneUpdates = 0;
  Future<void>? zoneReady;
  String? testPayload;
  final pending = <int>{777};
  final cancelled = <int>[];
  final times = <int, TZDateTime>{};
  late void Function(String?) tap;

  @override
  Future<void> initialize(void Function(String?) onTap) async {
    tap = onTap;
  }

  @override
  Future<String> updateTimeZone() async {
    zoneUpdates++;
    await zoneReady;
    return zone;
  }

  @override
  TZDateTime now() => current;
  @override
  Future<bool> launchedFrom(String payload) async => launch;
  @override
  Future<bool> isChannelEnabled(String channelId) async => channelEnabled;
  @override
  Future<Set<int>> pendingIds() async => {...pending};
  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
    times.remove(id);
    cancelled.add(id);
  }

  @override
  Future<void> schedule({
    required int id,
    required TZDateTime at,
    required bool weekly,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (failNext) {
      failNext = false;
      throw StateError('schedule failed');
    }
    scheduled++;
    pending.add(id);
    times[id] = at;
  }

  @override
  Future<void> show({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required String payload,
  }) async {
    testPayload = payload;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Notifications notifications;
  late _Permission permission;
  late _Diaries diaries;
  late ReminderService service;
  final reminder = Reminder(id: 1, hour: 21, minute: 30, weekdays: {1, 2});

  Future<void> initialize() async {
    await service.initialize();
    await service.reconcile();
  }

  setUp(() {
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    MoodiaryKVs.reminders.set(Reminder.encode([reminder]));
    MoodiaryKVs.reminderEnabled.set(true);
    notifications = _Notifications();
    permission = _Permission();
    diaries = _Diaries();
    service = ReminderService(notifications, permission, diaries);
  });

  tearDown(() async {
    service.dispose();
    await diaries.events.close();
    await getIt.reset();
  });

  test(
    'initialization sets up taps without waiting for reconciliation',
    () async {
      final ready = Completer<void>();
      notifications.zoneReady = ready.future;
      notifications.launch = true;
      try {
        await service.initialize().timeout(const Duration(seconds: 1));
        expect(service.launchedFromNotification, isTrue);
        expect(notifications.scheduled, 0);
        expect(permission.requests, 0);
      } finally {
        ready.complete();
        await service.reconcile();
      }
      expect(notifications.scheduled, 2);
    },
  );

  test(
    'setters reconcile once and external KV writes stay debounced',
    () async {
      await initialize();
      for (final action in <Future<void> Function()>[
        () => service.save(reminder.withEnabled(false)),
        () => service.setEnabled(false),
        () => service.setSkipIfWritten(false),
        () => service.remove(reminder.id),
      ]) {
        final reads = diaries.reads;
        final updates = notifications.zoneUpdates;
        await action();
        expect(diaries.reads, reads + 1);
        expect(notifications.zoneUpdates, updates + 1);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(diaries.reads, reads + 1);
        expect(notifications.zoneUpdates, updates + 1);
      }
      final reads = diaries.reads;
      MoodiaryKVs.reminders.set(Reminder.encode([reminder]));
      MoodiaryKVs.reminderEnabled.set(true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(diaries.reads, reads + 1);
      expect(notifications.pending, {777, 100009, 100010});
    },
  );

  test('tap action defaults to open app and persists without rescheduling', () {
    expect(MoodiaryKVs.reminderTapAction.get(), 'openApp');
    expect(service.tapAction, ReminderTapAction.openApp);
    var changes = 0;
    service.addListener(() => changes++);
    service.setTapAction(ReminderTapAction.newDiary);
    expect(MoodiaryKVs.reminderTapAction.get(), 'newDiary');
    expect(service.tapAction, ReminderTapAction.newDiary);
    service.setTapAction(ReminderTapAction.openApp);
    expect(MoodiaryKVs.reminderTapAction.get(), 'openApp');
    expect(service.tapAction, ReminderTapAction.openApp);
    expect(changes, 2);
    expect(notifications.scheduled, 0);
  });

  test('random salt persists and reconcile keeps, removes and replenishes one-shots', () async {
    expect(MoodiaryKVs.reminderSalt.get(), 0);
    final window = Reminder(
      id: 1,
      hour: 21,
      minute: 0,
      endHour: 23,
      endMinute: 0,
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    );
    MoodiaryKVs.reminders.set(Reminder.encode([window]));
    await initialize();
    final salt = MoodiaryKVs.reminderSalt.get()!;
    expect(salt, inInclusiveRange(1, 1 << 31));
    final first = Map<int, TZDateTime>.from(notifications.times);
    expect(first.length, 14);
    expect(service.next?.reminder.label, '21:00–23:00');
    await service.reconcile();
    expect(notifications.times, first);
    expect(notifications.scheduled, 14);
    diaries.written = true;
    await service.reconcile();
    expect(notifications.times.length, 14);
    expect(notifications.times.values.every((time) => time.day != 16), isTrue);
    expect(notifications.scheduled, 15);
    notifications.current = TZDateTime(UTC, 2026, 11, 17, 20);
    diaries.written = false;
    await service.reconcile();
    expect(MoodiaryKVs.reminderSalt.get(), salt);
    expect(notifications.times.length, 14);
    await service.save(
      Reminder(
        id: 1,
        hour: 20,
        minute: 0,
        endHour: 22,
        endMinute: 0,
        weekdays: window.weekdays,
      ),
    );
    expect(notifications.scheduled, greaterThan(15));
    await service.setEnabled(false);
    expect(notifications.pending, {777});
    await service.setEnabled(true);
    expect(MoodiaryKVs.reminderSalt.get(), salt);
    expect(notifications.times.length, 14);
  });

  test('reconcile diffs pending ids, changed times and switches, preserving foreign ids', () async {
    notifications.pending.add(100047);
    await initialize();
    expect(notifications.pending, {777, 100009, 100010});
    expect(notifications.scheduled, 2);
    await Future.wait([service.reconcile(), service.reconcile()]);
    expect(notifications.scheduled, 2);
    await service.save(Reminder(id: 1, hour: 22, minute: 15, weekdays: {1, 2}));
    expect(notifications.scheduled, 4);
    expect(notifications.cancelled, [100047]);
    expect(notifications.times[100009], TZDateTime(UTC, 2026, 11, 16, 22, 15));
    await service.setEnabled(false);
    expect(notifications.pending, {777});
  });

  test(
    'diary written today swaps and next date restores the weekly notification',
    () async {
      await initialize();
      diaries.written = true;
      await service.reconcile();
      expect(notifications.pending, {777, 200009, 100010});
      notifications.current = TZDateTime(UTC, 2026, 11, 17, 20);
      diaries.written = false;
      await service.reconcile();
      expect(notifications.pending, {777, 100009, 100010});
      expect(notifications.cancelled, containsAll([100009, 200009]));
    },
  );

  test(
    'changed time zone reschedules and channel permission is read on reconcile',
    () async {
      await initialize();
      notifications.zone = 'changed';
      notifications.channelEnabled = false;
      await service.reconcile();
      expect(notifications.scheduled, 4);
      expect(service.notificationsEnabled, isFalse);
      expect(permission.requests, 0);
    },
  );

  test(
    'failed apply can be retried without poisoning the reconcile queue',
    () async {
      await initialize();
      MoodiaryKVs.reminders.set(
        Reminder.encode([
          Reminder(id: 1, hour: 23, minute: 0, weekdays: {1}),
        ]),
      );
      notifications.failNext = true;
      await expectLater(service.reconcile(), throwsStateError);
      await service.reconcile();
      expect(notifications.pending, {777, 100009});
      expect(notifications.scheduled, 3);
    },
  );

  test('all diary events, including sync deletes, are debounced', () async {
    await initialize();
    final reads = diaries.reads;
    diaries.written = true;
    for (var index = 0; index < 20; index++) {
      diaries.events.add(DiaryDeleted('diary-$index', fromSync: true));
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(diaries.reads, reads + 1);
    expect(notifications.pending, contains(200009));
  });

  test(
    'cold and warm taps and test notifications share the reminder payload',
    () async {
      notifications.launch = true;
      await initialize();
      expect(service.launchedFromNotification, isTrue);
      var taps = 0;
      final subscription = service.taps.listen((_) => taps++);
      notifications.tap('other');
      notifications.tap('reminder');
      await Future<void>.delayed(Duration.zero);
      expect(taps, 1);
      await service.sendTest();
      expect(notifications.testPayload, 'reminder');
      await subscription.cancel();
    },
  );
}
