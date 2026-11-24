import 'package:moodiary_native/moodiary_native.dart';

abstract interface class NotificationPermission {
  Future<bool> isEnabled();
  Future<bool> request();
  Future<void> openSettings();
}

class DeviceNotificationPermission extends NotificationPermissionApi
    implements NotificationPermission {}
