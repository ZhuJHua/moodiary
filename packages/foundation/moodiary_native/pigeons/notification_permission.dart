import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/notification_permission.g.dart',
    dartPackageName: 'moodiary_native',
    kotlinOut: 'android/src/main/kotlin/cn/yooss/moodiary_native/NotificationPermission.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'cn.yooss.moodiary_native',
      includeErrorClass: false,
    ),
    swiftOut: 'ios/moodiary_native/Sources/moodiary_native/NotificationPermission.g.swift',
    swiftOptions: SwiftOptions(includeErrorClass: false),
  ),
)
@HostApi()
abstract class NotificationPermissionApi {
  @async
  bool isEnabled();
  @async
  bool request();
  void openSettings();
}
