import 'package:injectable/injectable.dart';
import 'package:moodiary_data/moodiary_data.dart';

import '../archive_apply.dart';
import '../sync.dart';
import 'local_archive.dart';

@LazySingleton(as: IBackupArchive)
class SyncBackupArchive implements IBackupArchive {
  const SyncBackupArchive()
    : this.withDependencies(LocalArchive.export, _restore);

  const SyncBackupArchive.withDependencies(
    this._exportArchive,
    this._importArchive,
  );

  final Future<String> Function() _exportArchive;
  final Future<SyncReport> Function(String) _importArchive;

  static Future<SyncReport> _restore(String zipPath) =>
      LocalArchive.import(zipPath, policy: const RestorePolicy());

  @override
  Future<String> export() => _exportArchive();

  @override
  Future<BackupImportResult> import(String zipPath) async {
    final report = await _importArchive(zipPath);
    return BackupImportResult(
      diaryCount: report.diaryCount,
      categoryCount: report.categoryCount,
      tagCount: report.tagCount,
      mediaCount: report.pulled.mediaFiles,
      failed: report.failed,
      cancelled: report.cancelled,
      skipped: report.skipped,
    );
  }
}
