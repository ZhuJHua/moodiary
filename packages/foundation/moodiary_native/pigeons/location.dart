import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/location.g.dart',
    dartPackageName: 'moodiary_native',
    kotlinOut: 'android/src/main/kotlin/cn/yooss/moodiary_native/Location.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'cn.yooss.moodiary_native',
      includeErrorClass: false,
    ),
    swiftOut: 'ios/moodiary_native/Sources/moodiary_native/Location.g.swift',
    swiftOptions: SwiftOptions(includeErrorClass: false),
  ),
)
enum LocationAuthorization { granted, denied, deniedForever }

class LocationFix {
  LocationFix({
    required this.latitude,
    required this.longitude,
    required this.ageMillis,
  });
  double latitude;
  double longitude;

  /// How long ago the fix was taken, as the platform reports it.
  int ageMillis;
}

@HostApi()
abstract class LocationApi {
  /// Prompts only when the user has not decided yet.
  @async
  LocationAuthorization requestPermission();

  @async
  bool isServiceEnabled();

  LocationFix? lastKnown();

  /// Returns a fresh fix, targeting 100 meters when [precise] is requested.
  /// At the deadline or once sources are exhausted, returns the best available fix.
  @async
  LocationFix? current(bool precise, int timeoutMillis);
}
