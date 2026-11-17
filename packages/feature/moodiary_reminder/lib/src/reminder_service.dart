import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:injectable/injectable.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'reminder.dart';
import 'reminder_scheduler.dart';

enum ReminderTapAction { openApp, newDiary }

@lazySingleton
class ReminderService extends ChangeNotifier {
  ReminderService(this._notifications, this.permission, this._diaries);

  static const channelId = 'diary_reminder';
  static const payload = 'reminder';
  final LocalNotifications _notifications;
  final NotificationPermission permission;
  final DiaryRepository _diaries;
  final _taps = StreamController<void>.broadcast();
  final _applied = <int, String>{};
  Future<void> _queue = Future.value();
  Future<void>? _initialization;
  StreamSubscription<dynamic>? _diarySubscription;
  AppLifecycleListener? _lifecycle;
  Timer? _debounce;
  Timer? _midnight;
  String? _zone;
  bool _writtenToday = false;
  bool _disposed = false;
  bool launchedFromNotification = false;
  bool notificationsEnabled = true;

  Stream<void> get taps => _taps.stream;
  List<Reminder> get reminders => Reminder.decode(MoodiaryKVs.reminders.get()!);
  bool get enabled => MoodiaryKVs.reminderEnabled.get()!;
  bool get skipIfWritten => MoodiaryKVs.reminderSkipIfWritten.get()!;
  ReminderTapAction get tapAction =>
      MoodiaryKVs.reminderTapAction.get() == ReminderTapAction.newDiary.name
      ? ReminderTapAction.newDiary
      : ReminderTapAction.openApp;
  TZDateTime get now => _notifications.now();
  int get _salt {
    final stored = MoodiaryKVs.reminderSalt.get()!;
    if (stored != 0) return stored;
    final salt = Random.secure().nextInt(1 << 31) + 1;
    MoodiaryKVs.reminderSalt.set(salt);
    return salt;
  }

  ReminderNotification? get next => ReminderScheduler.next(
    ReminderScheduler.desired(
      reminders: reminders,
      enabled: enabled,
      skipIfWritten: skipIfWritten,
      writtenToday: _writtenToday,
      now: now,
      salt: _salt,
    ),
  );

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _notifications.initialize((value) {
      if (value == payload && !_disposed) {
        launchedFromNotification = true;
        _taps.add(null);
      }
    });
    launchedFromNotification = await _notifications.launchedFrom(payload);
    _diarySubscription = _diaries.diaryEvents.listen((_) => _changed());
    MoodiaryKVs.reminders.getNotifier().addListener(_changed);
    MoodiaryKVs.reminderEnabled.getNotifier().addListener(_changed);
    MoodiaryKVs.reminderSkipIfWritten.getNotifier().addListener(_changed);
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  void _changed() {
    if (_disposed) return;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _refresh);
  }

  void _refresh() {
    if (_disposed) return;
    unawaited(
      reconcile().catchError((Object error, StackTrace stack) {
        logger.e(
          'Reminder reconciliation failed',
          error: error,
          stackTrace: stack,
        );
      }),
    );
  }

  Future<void> reconcile() {
    final operation = _queue.then((_) => _reconcile());
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _reconcile() async {
    if (_disposed) return;
    final zone = await _notifications.updateTimeZone();
    if (_zone != zone) {
      _zone = zone;
      _applied.clear();
    }
    final current = now;
    _writtenToday = await _diaries.hasDiaryOnDate(current);
    await checkPermission();
    final desired = ReminderScheduler.desired(
      reminders: reminders,
      enabled: enabled,
      skipIfWritten: skipIfWritten,
      writtenToday: _writtenToday,
      now: current,
      salt: _salt,
    );
    final pending = await _notifications.pendingIds();
    final desiredIds = desired.map((notification) => notification.id).toSet();
    for (final id in pending.where(ReminderScheduler.ownsId)) {
      if (!desiredIds.contains(id)) {
        await _notifications.cancel(id);
        _applied.remove(id);
      }
    }
    final text =
        '${l10n.reminder.notificationTitle}:${l10n.reminder.notificationBody}:${l10n.reminder.title}';
    for (final notification in desired) {
      final signature =
          '${notification.weekly}:${notification.signature}:$text';
      if (pending.contains(notification.id) &&
          _applied[notification.id] == signature) {
        continue;
      }
      _applied.remove(notification.id);
      await _notifications.schedule(
        id: notification.id,
        at: notification.at,
        weekly: notification.weekly,
        channelId: channelId,
        channelName: l10n.reminder.title,
        title: l10n.reminder.notificationTitle,
        body: l10n.reminder.notificationBody,
        payload: payload,
      );
      _applied[notification.id] = signature;
    }
    _midnight?.cancel();
    final tomorrow = TZDateTime(
      current.location,
      current.year,
      current.month,
      current.day + 1,
    );
    _midnight = Timer(tomorrow.difference(current), _refresh);
    if (!_disposed) notifyListeners();
  }

  Future<void> save(Reminder reminder) async {
    final items = reminders;
    final updated = [...items.where((item) => item.id != reminder.id), reminder]
      ..sort((first, second) => first.id.compareTo(second.id));
    await _write(() => MoodiaryKVs.reminders.set(Reminder.encode(updated)));
  }

  Future<void> remove(int id) async {
    final remaining = reminders.where((item) => item.id != id).toList();
    await _write(() {
      MoodiaryKVs.reminders.set(Reminder.encode(remaining));
      if (remaining.isEmpty) MoodiaryKVs.reminderEnabled.set(false);
    });
  }

  Future<void> setEnabled(bool value) =>
      _write(() => MoodiaryKVs.reminderEnabled.set(value));

  Future<void> setSkipIfWritten(bool value) =>
      _write(() => MoodiaryKVs.reminderSkipIfWritten.set(value));

  Future<void> _write(VoidCallback write) async {
    write();
    try {
      await reconcile();
    } finally {
      _debounce?.cancel();
    }
  }

  void setTapAction(ReminderTapAction value) {
    MoodiaryKVs.reminderTapAction.set(value.name);
    notifyListeners();
  }

  Future<void> sendTest() => _notifications.show(
    id: 300000,
    channelId: channelId,
    channelName: l10n.reminder.title,
    title: l10n.reminder.notificationTitle,
    body: l10n.reminder.notificationBody,
    payload: payload,
  );

  Future<bool> checkPermission() async {
    notificationsEnabled =
        await permission.isEnabled() &&
        await _notifications.isChannelEnabled(channelId);
    if (!_disposed) notifyListeners();
    return notificationsEnabled;
  }

  @disposeMethod
  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _midnight?.cancel();
    _lifecycle?.dispose();
    unawaited(_diarySubscription?.cancel());
    MoodiaryKVs.reminders.getNotifier().removeListener(_changed);
    MoodiaryKVs.reminderEnabled.getNotifier().removeListener(_changed);
    MoodiaryKVs.reminderSkipIfWritten.getNotifier().removeListener(_changed);
    unawaited(_taps.close());
    super.dispose();
  }
}
