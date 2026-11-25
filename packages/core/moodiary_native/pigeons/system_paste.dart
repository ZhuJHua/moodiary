import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/system_paste.g.dart',
    dartPackageName: 'moodiary_native',
    swiftOut: 'ios/moodiary_native/Sources/moodiary_native/SystemPaste.g.swift',
    swiftOptions: SwiftOptions(includeErrorClass: false),
  ),
)
@HostApi()
abstract class SystemPasteApi {
  void setEnabled(bool enabled);
}

@FlutterApi()
abstract class SystemPasteClient {
  void onPaste();
}
