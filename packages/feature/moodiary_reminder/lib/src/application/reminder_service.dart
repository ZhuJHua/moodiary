import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:injectable/injectable.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:synchronized/synchronized.dart';

import '../data/reminder.dart';
import 'reminder_scheduler.dart';

enum ReminderTapAction { openApp, newDiary }

@internal
({String title, String body}) reminderNotificationCopy(
  Translations l10n,
  int hour,
) => switch (hour) {
  >= 5 && < 11 => (
    title: l10n.reminder.copy.morning.title,
    body: l10n.reminder.copy.morning.body,
  ),
  >= 11 && < 14 => (
    title: l10n.reminder.copy.noon.title,
    body: l10n.reminder.copy.noon.body,
  ),
  >= 14 && < 18 => (
    title: l10n.reminder.copy.afternoon.title,
    body: l10n.reminder.copy.afternoon.body,
  ),
  >= 18 && < 23 => (
    title: l10n.reminder.copy.evening.title,
    body: l10n.reminder.copy.evening.body,
  ),
  _ => (
    title: l10n.reminder.copy.night.title,
    body: l10n.reminder.copy.night.body,
  ),
};

Future<void> cancelReminderNotifications(
  LocalNotifications notifications,
) async {
  final pending = await notifications.pendingIds();
  for (final id in pending.where(ReminderScheduler.ownsId)) {
    await notifications.cancel(id);
  }
}

@lazySingleton
class ReminderService extends ChangeNotifier {
  ReminderService(this._notifications, this.permission);

  static const channelId = 'diary_reminder';
  static const payload = 'reminder';
  final LocalNotifications _notifications;
  final NotificationPermission permission;
  final _taps = StreamController<void>.broadcast();
  final _applied = <int, String>{};
  final _lock = Lock();
  StreamSubscription<void>? _locale;
  List<Reminder>? _reminders;
  Future<void>? _initialization;
  AppLifecycleListener? _lifecycle;
  Timer? _debounce;
  bool _disposed = false;
  bool launchedFromNotification = false;
  bool _notificationsEnabled = true;

  Stream<void> get taps => _taps.stream;
  List<Reminder> get reminders =>
      _reminders ??= Reminder.decode(MoodiaryKVs.reminders.get()!);
  bool get notificationsEnabled => _notificationsEnabled;
  bool get enabled => MoodiaryKVs.reminderEnabled.get()!;
  ReminderTapAction get tapAction =>
      MoodiaryKVs.reminderTapAction.get() == ReminderTapAction.newDiary.name
      ? ReminderTapAction.newDiary
      : ReminderTapAction.openApp;
  TZDateTime get now => _notifications.now();
  ReminderNotification? get next => ReminderScheduler.desired(
    reminders: reminders,
    enabled: enabled,
    now: now,
  ).firstOrNull;

  ({
    String channelId,
    String channelName,
    String title,
    String body,
    String payload,
  })
  _content(int hour) {
    final copy = reminderNotificationCopy(l10n, hour);
    return (
      channelId: channelId,
      channelName: l10n.reminder.title,
      title: copy.title,
      body: copy.body,
      payload: payload,
    );
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _notifications.initialize((value) {
      if (value == payload && !_disposed) {
        launchedFromNotification = true;
        _taps.add(null);
      }
    });
    launchedFromNotification = await _notifications.launchedFrom(payload);
    MoodiaryKVs.reminders.getNotifier().addListener(_remindersChanged);
    MoodiaryKVs.reminderEnabled.getNotifier().addListener(_changed);
    _locale = LocaleSettings.getLocaleStream().listen((_) => _refresh());
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  void _remindersChanged() {
    _reminders = null;
    _changed();
  }

  void _changed() {
    if (_disposed) return;
    notifyListeners();
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    if (_disposed) return;
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

  Future<void> reconcile() => _lock.synchronized(_reconcile);

  Future<void> _reconcile() async {
    if (_disposed) return;
    if (!enabled) {
      await cancelReminderNotifications(_notifications);
      _applied.clear();
      if (!_disposed) notifyListeners();
      return;
    }
    await _notifications.updateTimeZone();
    await checkPermission();
    final desired = ReminderScheduler.desired(
      reminders: reminders,
      enabled: enabled,
      now: now,
    );
    final pending = await _notifications.pendingIds();
    final desiredIds = desired.map((notification) => notification.id).toSet();
    for (final id in pending.where(ReminderScheduler.ownsId)) {
      if (!desiredIds.contains(id)) {
        await _notifications.cancel(id);
        _applied.remove(id);
      }
    }
    for (final notification in desired) {
      final content = _content(notification.reminder.hour);
      final text = '${content.title}:${content.body}:${content.channelName}';
      final signature = '${notification.signature}:$text';
      if (pending.contains(notification.id) &&
          _applied[notification.id] == signature) {
        continue;
      }
      _applied.remove(notification.id);
      await _notifications.schedule(
        id: notification.id,
        at: notification.template,
        weekly: true,
        channelId: content.channelId,
        channelName: content.channelName,
        title: content.title,
        body: content.body,
        payload: content.payload,
      );
      _applied[notification.id] = signature;
    }
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

  Future<void> sendTest() async {
    await _notifications.updateTimeZone();
    final content = _content(now.hour);
    await _notifications.show(
      id: 300000,
      channelId: content.channelId,
      channelName: content.channelName,
      title: content.title,
      body: content.body,
      payload: content.payload,
    );
  }

  Future<bool> checkPermission() async {
    final enabled =
        await permission.isEnabled() &&
        await _notifications.isChannelEnabled(channelId);
    if (_notificationsEnabled != enabled) {
      _notificationsEnabled = enabled;
      if (!_disposed) notifyListeners();
    }
    return enabled;
  }

  @disposeMethod
  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _lifecycle?.dispose();
    unawaited(_locale?.cancel());
    MoodiaryKVs.reminders.getNotifier().removeListener(_remindersChanged);
    MoodiaryKVs.reminderEnabled.getNotifier().removeListener(_changed);
    unawaited(_taps.close());
    super.dispose();
  }
}
