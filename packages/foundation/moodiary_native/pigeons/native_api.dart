import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/native_api.g.dart',
    dartPackageName: 'moodiary_native',
    kotlinOut:
        'android/src/main/kotlin/cn/yooss/moodiary_native/NativeApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'cn.yooss.moodiary_native'),
    swiftOut: 'ios/moodiary_native/Sources/moodiary_native/NativeApi.g.swift',
  ),
)
// Android only: WebView text-selection handles are drawn by the Activity theme.
@HostApi()
abstract class SelectionHandleApi {
  void setColor(int argb);
}
