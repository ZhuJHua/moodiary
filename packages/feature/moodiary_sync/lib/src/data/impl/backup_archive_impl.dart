import 'package:moodiary_data/moodiary_data.dart';

import 'local_archive.dart';

/// [IBackupArchive] 的同步引擎实现。导出/导入页在 moodiary_export，两个 feature 包
/// 不能互相 import，故经 moodiary_data 的端口与 app 层 DI 相接。
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
