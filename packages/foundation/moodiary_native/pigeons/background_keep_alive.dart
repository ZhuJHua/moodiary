import 'package:pigeon/pigeon.dart';

// 后台保活：安卓在 specialUse 前台服务里跑常驻通知，iOS 循环播放静音音频；
// 常驻逻辑本身仍在 Dart 侧（哪个进程活着由系统决定）
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

  // 通知权限只决定常驻通知能否显示，没有它前台服务照样在跑
  bool isNotificationsEnabled();

  bool requestNotifications();

  // 安卓：启动/停止前台服务，标题与正文由 Dart 传入（来自 l10n）。
  // iOS：启动/停止静音音频循环，另外两个参数忽略。
  void setKeepAlive(
    bool enabled,
    String notificationTitle,
    String notificationText,
  );

  // 系统设置里本应用的详情页，用户拒绝过权限后从这里手动打开
  void openAppSettings();
}
