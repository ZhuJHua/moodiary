import 'package:pigeon/pigeon.dart';

// 首个生成 Swift 的文件，Swift 的 PigeonError 由它带出
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/editor_keyboard.g.dart',
    dartPackageName: 'moodiary_native',
    kotlinOut:
        'android/src/main/kotlin/cn/yooss/moodiary_native/EditorKeyboard.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'cn.yooss.moodiary_native',
      includeErrorClass: false,
    ),
    swiftOut:
        'ios/moodiary_native/Sources/moodiary_native/EditorKeyboard.g.swift',
  ),
)
class KeyboardEvent {
  KeyboardEvent({
    required this.visible,
    required this.height,
    required this.durationMs,
    required this.isStart,
    required this.floating,
  });

  bool visible;

  // 动画结束时停靠键盘的逻辑像素高度，安卓不含导航栏
  double height;

  int durationMs;

  bool isStart;

  bool floating;
}

@HostApi()
abstract class EditorKeyboardApi {
  void attach(int webViewId);

  void detach();

  bool setKeyboardSuppressed(bool suppressed);

  // Flutter 输入框会拿走安卓视图焦点 / iOS first responder，WebView 不先拿回来 JS focus 无效
  void focusWebView();
}

@EventChannelApi()
abstract class EditorKeyboardEvents {
  KeyboardEvent keyboardEvents();
}
