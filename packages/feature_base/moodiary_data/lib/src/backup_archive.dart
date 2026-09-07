abstract class IBackupArchive {
  Future<String> export();

  Future<BackupImportResult> import(String zipPath);
}

class BackupImportResult {
  final int diaryCount;

  final int categoryCount;

  final int mediaInfoCount;

  final int failed;

  final bool cancelled;

  final int skipped;

  const BackupImportResult({
    required this.diaryCount,
    required this.categoryCount,
    required this.mediaInfoCount,
    required this.failed,
    this.cancelled = false,
    this.skipped = 0,
  });
}
