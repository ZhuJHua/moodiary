import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/selection_handle.g.dart',
    dartPackageName: 'moodiary_native',
    kotlinOut:
        'android/src/main/kotlin/cn/yooss/moodiary_native/SelectionHandle.g.kt',
    kotlinOptions: KotlinOptions(package: 'cn.yooss.moodiary_native'),
  ),
)
@HostApi()
abstract class SelectionHandleApi {
  void setColor(int argb);
}
