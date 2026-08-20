import 'package:moodiary_data/moodiary_data.dart';

import 'local_archive.dart';

/// [IBackupArchive] 的同步引擎实现。
class SyncBackupArchive implements IBackupArchive {
  const SyncBackupArchive();

  @override
  Future<String> export() => LocalArchive.export();

  @override
  Future<String> import(String zipPath) async {
    final report = await LocalArchive.import(zipPath);
    return report.toString();
  }
}
