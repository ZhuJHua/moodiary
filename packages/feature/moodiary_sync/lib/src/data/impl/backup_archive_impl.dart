import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_sync/src/data/sync_cancellation_token.dart';

import '../archive_apply.dart';
import '../sync.dart';
import 'local_archive.dart';

class SyncBackupArchive implements IBackupArchive {
  SyncBackupArchive(LocalArchive archive)
    : this.withDependencies(
        () => archive.export(cancellation: SyncCancellationToken()),
        (path) => archive.import(
          path,
          policy: const RestorePolicy(),
          cancellation: SyncCancellationToken(),
        ),
      );

  const SyncBackupArchive.withDependencies(
    this._exportArchive,
    this._importArchive,
  );

  final Future<String> Function() _exportArchive;
  final Future<SyncReport> Function(String) _importArchive;

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
