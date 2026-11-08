import 'package:pigeon/pigeon.dart';

// 后台保活：安卓只负责申请电池优化白名单，iOS 负责静音音频；真正的常驻逻辑在 Dart 侧
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/background_keep_alive.g.dart',
    dartPackageName: 'moodiary_native',
    kotlinOut: 'android/src/main/kotlin/cn/yooss/moodiary_native/BackgroundKeepAlive.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'cn.yooss.moodiary_native',
      includeErrorClass: false,
    ),
    swiftOut: 'ios/moodiary_native/Sources/moodiary_native/BackgroundKeepAlive.g.swift',
    swiftOptions: SwiftOptions(includeErrorClass: false),
  ),
)
@HostApi()
abstract class BackgroundKeepAliveApi {
  bool isExempt();

  bool requestExemption();

  void setSilentAudio(bool enabled);
}
