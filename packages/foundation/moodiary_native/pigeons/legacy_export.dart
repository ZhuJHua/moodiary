import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/legacy_export.g.dart',
    dartPackageName: 'moodiary_native',
    kotlinOut:
        'android/src/main/kotlin/cn/yooss/moodiary_native/LegacyExport.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'cn.yooss.moodiary_native',
      includeErrorClass: false,
    ),
  ),
)
class SavedFile {
  SavedFile({required this.uri, required this.size, required this.displayName});
  String uri;
  int size;
  String displayName;
}

@HostApi()
abstract class LegacyExportApi {
  int availableCacheBytes();
  @async
  SavedFile saveToDownloads(String srcPath, String displayName);
}
