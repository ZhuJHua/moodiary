import 'package:injectable/injectable.dart';
import 'package:moodiary_data/moodiary_data.dart';

import '../archive_apply.dart';
import 'local_archive.dart';

@LazySingleton(as: IBackupArchive)
class SyncBackupArchive implements IBackupArchive {
  const SyncBackupArchive();

  @override
  Future<String> export() => LocalArchive.export();

  @override
  Future<BackupImportResult> import(String zipPath) async {
    final report = await LocalArchive.import(
      zipPath,
      policy: const RestorePolicy(),
    );
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
