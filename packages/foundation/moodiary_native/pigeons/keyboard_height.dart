import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/keyboard_height.g.dart',
    dartPackageName: 'moodiary_native',
    kotlinOut:
        'android/src/main/kotlin/cn/yooss/moodiary_native/KeyboardHeight.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'cn.yooss.moodiary_native',
      includeErrorClass: false,
    ),
    swiftOut:
        'ios/moodiary_native/Sources/moodiary_native/KeyboardHeight.g.swift',
    swiftOptions: SwiftOptions(includeErrorClass: false),
  ),
)
@EventChannelApi()
abstract class KeyboardHeightEvents {
  // Docked keyboard height in logical pixels, sent when the keyboard starts
  // moving (its final height), 0 once it hides. Android includes the nav bar,
  // like Flutter's viewInsets.
  double keyboardHeight();
}
