import 'dart:io';

import 'legacy_export.g.dart';

abstract final class LegacyExport {
  static LegacyExportApi get _android {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Legacy export requires Android');
    }
    return LegacyExportApi();
  }

  static Future<int> availableCacheBytes() async =>
      _android.availableCacheBytes();

  static Future<SavedFile> saveToDownloads(
    String path,
    String displayName,
  ) async => _android.saveToDownloads(path, displayName);
}
