import 'package:pigeon/pigeon.dart';

// 安卓后台保活：specialUse 前台服务显示常驻通知，服务逻辑仍在 Dart 侧。
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/background_keep_alive.g.dart',
    dartPackageName: 'moodiary_native',
    kotlinOut: 'android/src/main/kotlin/cn/yooss/moodiary_native/BackgroundKeepAlive.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'cn.yooss.moodiary_native',
      includeErrorClass: false,
    ),
  ),
)
@HostApi()
abstract class BackgroundKeepAliveApi {
  bool isExempt();

  void requestExemption();

  // 通知文案由 Dart l10n 传入。
  void setKeepAlive(bool enabled, String notificationText, String stopLabel);

  // 系统设置里本应用的详情页
  void openAppSettings();
}

@FlutterApi()
abstract class BackgroundKeepAliveEvents {
  @async
  void onStopRequested();
}
