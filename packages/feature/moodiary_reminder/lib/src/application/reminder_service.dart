import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:injectable/injectable.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:synchronized/synchronized.dart';

import '../data/reminder.dart';
import '../data/reminder_notifications.dart';

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

@lazySingleton
class ReminderService extends ChangeNotifier {
  ReminderService(this._notifications, this.permission);

  final ReminderNotifications _notifications;
  final NotificationPermission permission;
  final _taps = StreamController<void>.broadcast();
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
  DateTime get now => DateTime.now();

  DateTime? get next {
    if (!enabled) return null;
    final reference = now;
    DateTime? earliest;
    for (var offset = -1; offset <= 7; offset++) {
      final date = DateTime.utc(
        reference.year,
        reference.month,
        reference.day + offset,
      );
      for (final reminder in reminders) {
        if (!reminder.enabled || !reminder.weekdays.contains(date.weekday)) {
          continue;
        }
        final at = _localOccurrence(date, reminder.hour, reminder.minute);
        if (at.isAfter(reference) &&
            (earliest == null || at.isBefore(earliest))) {
          earliest = at;
        }
      }
    }
    return earliest;
  }

  static DateTime _localOccurrence(DateTime date, int hour, int minute) {
    final wallTime = DateTime.utc(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    final precedingOffset = wallTime
        .subtract(const Duration(days: 1))
        .toLocal()
        .timeZoneOffset;
    final first = wallTime.subtract(precedingOffset).toLocal();
    if (first.timeZoneOffset == precedingOffset) return first;
    final adjusted = wallTime.subtract(first.timeZoneOffset).toLocal();
    return adjusted.timeZoneOffset == first.timeZoneOffset ? adjusted : first;
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    _notifications.setTapHandler(_onTap);
    if (await _notifications.consumeLaunchTap()) _onTap();
    if (_disposed) return;
    MoodiaryKVs.reminders.getNotifier().addListener(_remindersChanged);
    MoodiaryKVs.reminderEnabled.getNotifier().addListener(_changed);
    _locale = LocaleSettings.getLocaleStream().listen((_) => _refresh());
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    _refresh();
  }

  void _onTap() {
    if (_disposed) return;
    launchedFromNotification = true;
    _taps.add(null);
  }

  Future<void> _onResume() async {
    try {
      await checkPermission();
      _refresh();
    } catch (error, stack) {
      logger.e(
        'Reminder permission check failed',
        error: error,
        stackTrace: stack,
      );
    }
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
    await _notifications.setSchedule(
      ReminderSchedule(
        channelName: l10n.reminder.channelName,
        slots: [
          if (enabled)
            for (final reminder in reminders)
              if (reminder.enabled) _slot(reminder),
        ],
      ),
    );
    if (!_disposed) notifyListeners();
  }

  ReminderSlot _slot(Reminder reminder) {
    final copy = reminderNotificationCopy(l10n, reminder.hour);
    return ReminderSlot(
      id: reminder.id,
      hour: reminder.hour,
      minute: reminder.minute,
      weekdays: reminder.weekdays.toList()..sort(),
      title: copy.title,
      body: copy.body,
    );
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
    _debounce?.cancel();
    await reconcile();
  }

  void setTapAction(ReminderTapAction value) {
    MoodiaryKVs.reminderTapAction.set(value.name);
    notifyListeners();
  }

  Future<void> sendTest() async {
    final copy = reminderNotificationCopy(l10n, now.hour);
    await _notifications.showTest(
      copy.title,
      copy.body,
      l10n.reminder.channelName,
    );
  }

  Future<bool> checkPermission() async {
    final enabled =
        await permission.isEnabled() && await _notifications.isChannelEnabled();
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
    if (_initialization != null) _notifications.setTapHandler(null);
    _debounce?.cancel();
    _lifecycle?.dispose();
    unawaited(_locale?.cancel());
    MoodiaryKVs.reminders.getNotifier().removeListener(_remindersChanged);
    MoodiaryKVs.reminderEnabled.getNotifier().removeListener(_changed);
    unawaited(_taps.close());
    super.dispose();
  }
}
