import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract interface class NotificationPermission {
  Future<bool> isEnabled();
  Future<bool> request();
  Future<void> openSettings();
}

class DeviceNotificationPermission implements NotificationPermission {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<bool> isEnabled() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    return (await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.checkPermissions())
            ?.isEnabled ??
        false;
  }

  @override
  Future<bool> request() async {
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true, badge: false);
    }
    return isEnabled();
  }

  @override
  Future<void> openSettings() async {
    await _plugin.openAppNotificationSettings();
  }
}

abstract interface class LocalNotifications {
  Future<void> initialize(void Function(String?) onTap);
  Future<void> updateTimeZone();
  tz.TZDateTime now();
  Future<bool> launchedFrom(String payload);
  Future<bool> isChannelEnabled(String channelId);
  Future<Set<int>> pendingIds();
  Future<void> cancel(int id);
  Future<void> schedule({
    required int id,
    required tz.TZDateTime at,
    required bool weekly,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required String payload,
  });
  Future<void> show({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required String payload,
  });
}

class DeviceLocalNotifications implements LocalNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize(void Function(String?) onTap) async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<void> updateTimeZone() async {
    final id = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.Location location;
    try {
      location = tz.getLocation(id);
    } catch (_) {
      location = parseFixedOffsetTimeZone(id);
    }
    tz.setLocalLocation(location);
  }

  @override
  tz.TZDateTime now() => tz.TZDateTime.now(tz.local);

  @override
  Future<bool> launchedFrom(String payload) async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true &&
        details?.notificationResponse?.payload == payload;
  }

  @override
  Future<bool> isChannelEnabled(String channelId) async {
    if (!Platform.isAndroid) return true;
    final channels = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.getNotificationChannels();
    return !(channels ?? []).any(
      (channel) =>
          channel.id == channelId && channel.importance == Importance.none,
    );
  }

  @override
  Future<Set<int>> pendingIds() async => {
    for (final request in await _plugin.pendingNotificationRequests())
      request.id,
  };

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  NotificationDetails _details(String channelId, String channelName) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          icon: 'ic_notification',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          channelShowBadge: false,
        ),
        iOS: const DarwinNotificationDetails(presentBadge: false),
      );

  @override
  Future<void> schedule({
    required int id,
    required tz.TZDateTime at,
    required bool weekly,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required String payload,
  }) => _plugin.zonedSchedule(
    id: id,
    scheduledDate: at,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: weekly
        ? DateTimeComponents.dayOfWeekAndTime
        : null,
    notificationDetails: _details(channelId, channelName),
    title: title,
    body: body,
    payload: payload,
  );

  @override
  Future<void> show({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required String payload,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    payload: payload,
    notificationDetails: _details(channelId, channelName),
  );
}

@visibleForTesting
tz.Location parseFixedOffsetTimeZone(String id) {
  final match = RegExp(r'^(?:GMT|UTC)([+-])(\d{1,2})(?::?(\d{2}))?$')
      .firstMatch(id);
  if (match == null) return tz.UTC;
  final hours = int.parse(match[2]!);
  final minutes = int.parse(match[3] ?? '0');
  if (hours > 23 || minutes > 59) return tz.UTC;
  final offset = (hours * 60 + minutes) * (match[1] == '-' ? -1 : 1);
  return tz.Location(id, const [], const [], [
    tz.TimeZone(Duration(minutes: offset), isDst: false, abbreviation: id),
  ]);
}
