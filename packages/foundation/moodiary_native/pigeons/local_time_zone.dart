import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/local_time_zone.g.dart',
    dartPackageName: 'moodiary_native',
    kotlinOut:
        'android/src/main/kotlin/cn/yooss/moodiary_native/LocalTimeZone.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'cn.yooss.moodiary_native',
      includeErrorClass: false,
    ),
    swiftOut:
        'ios/moodiary_native/Sources/moodiary_native/LocalTimeZone.g.swift',
    swiftOptions: SwiftOptions(includeErrorClass: false),
  ),
)
@HostApi()
abstract class LocalTimeZoneApi {
  String localTimeZoneId();
}
