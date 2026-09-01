import 'package:injectable/injectable.dart';
import 'package:moodiary_data/moodiary_data.dart';

import 'local_archive.dart';

/// [IBackupArchive] 的同步引擎实现。
///
/// 归档实现在 sync、页面在 export —— 两个 feature 不能互相 import，接线只能由
/// 组合根完成；类自注册后这条知识就落在实现类上，app 不必再认识两边。
@LazySingleton(as: IBackupArchive)
class SyncBackupArchive implements IBackupArchive {
  const SyncBackupArchive();

  @override
  Future<String> export() => LocalArchive.export();

  @override
  Future<BackupImportResult> import(String zipPath) async {
    // 「从备份恢复」是恢复不是同步：只增不删（见 [SyncPullMode.restore]）。
    final report = await LocalArchive.import(zipPath, mode: .restore);
    return BackupImportResult(
      diaryCount: report.diaryCount,
      categoryCount: report.categoryCount,
      mediaInfoCount: report.mediaInfoCount,
      failed: report.failed,
      cancelled: report.cancelled,
      skipped: report.skipped,
    );
  }
}
