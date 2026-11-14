import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/html_clipboard.g.dart',
  dartPackageName: 'moodiary_native',
  kotlinOut: 'android/src/main/kotlin/cn/yooss/moodiary_native/HtmlClipboard.g.kt',
  kotlinOptions: KotlinOptions(package: 'cn.yooss.moodiary_native'),
  swiftOut: 'ios/moodiary_native/Sources/moodiary_native/HtmlClipboard.g.swift',
  swiftOptions: SwiftOptions(),
))
class HtmlClipboardContent {
  HtmlClipboardContent({required this.text, this.html});
  String text;
  String? html;
}

@HostApi()
abstract class HtmlClipboardApi {
  @async
  HtmlClipboardContent? read();
  void write(HtmlClipboardContent content);
}
