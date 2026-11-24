import 'dart:ui' show VoidCallback;

import 'package:injectable/injectable.dart';
import 'package:moodiary_native/moodiary_native.dart';

abstract interface class ReminderNotifications {
  void setTapHandler(VoidCallback? handler);
  Future<bool> consumeLaunchTap();
  Future<void> setSchedule(ReminderSchedule schedule);
  Future<void> showTest(String title, String body, String channelName);
  Future<bool> isChannelEnabled();
}

@LazySingleton(as: ReminderNotifications)
class NativeReminderNotifications
    implements ReminderNotifications, ReminderNotificationsEvents {
  final _api = ReminderNotificationsApi();
  VoidCallback? _handler;

  @override
  void setTapHandler(VoidCallback? handler) {
    _handler = handler;
    ReminderNotificationsEvents.setUp(handler == null ? null : this);
  }

  @override
  void onTap() => _handler?.call();

  @override
  Future<bool> consumeLaunchTap() => _api.consumeLaunchTap();

  @override
  Future<void> setSchedule(ReminderSchedule schedule) =>
      _api.setSchedule(schedule);

  @override
  Future<void> showTest(String title, String body, String channelName) =>
      _api.showTest(title, body, channelName);

  @override
  Future<bool> isChannelEnabled() => _api.isChannelEnabled();
}
