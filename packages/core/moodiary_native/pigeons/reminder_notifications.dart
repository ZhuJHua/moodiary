import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/reminder_notifications.g.dart',
    dartPackageName: 'moodiary_native',
    kotlinOut: 'android/src/main/kotlin/cn/yooss/moodiary_native/ReminderNotifications.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'cn.yooss.moodiary_native',
      includeErrorClass: false,
    ),
    swiftOut: 'ios/moodiary_native/Sources/moodiary_native/ReminderNotifications.g.swift',
    swiftOptions: SwiftOptions(includeErrorClass: false),
  ),
)
class ReminderSlot {
  ReminderSlot({
    required this.id,
    required this.hour,
    required this.minute,
    required this.weekdays,
    required this.title,
    required this.body,
  });

  int id;
  int hour;
  int minute;
  List<int> weekdays;
  String title;
  String body;
}

class ReminderSchedule {
  ReminderSchedule({required this.slots, required this.channelName});

  List<ReminderSlot> slots;
  String channelName;
}

@HostApi()
abstract class ReminderNotificationsApi {
  @async
  void setSchedule(ReminderSchedule schedule);
  @async
  void clear();
  @async
  void showTest(String title, String body, String channelName);
  bool isChannelEnabled();
  bool consumeLaunchTap();
}

@FlutterApi()
abstract class ReminderNotificationsEvents {
  void onTap();
}
