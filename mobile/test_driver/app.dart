import 'package:flutter_driver/driver_extension.dart';
import 'package:moodiary/main.dart' as app;

/// 驱动入口：启用 Flutter Driver 扩展后照常启动 app，供 `flutter_driver_command` 远程操控。
void main() {
  enableFlutterDriverExtension();
  app.main();
}
