typedef LegacyExportSummary = ({
  int databaseBytes,
  int mediaCount,
  int mediaBytes,
});

abstract interface class LegacyDataExporter {
  Future<LegacyExportSummary> inspect();

  Future<String> export({
    required void Function(int completed, int total) onProgress,
    required bool Function() isCancelled,
  });
}

class LegacyExportCancelled implements Exception {
  const LegacyExportCancelled();
}

class LegacyExportInsufficientSpace implements Exception {
  const LegacyExportInsufficientSpace();
}

class LegacyExportFileTooLarge implements Exception {
  const LegacyExportFileTooLarge(this.path);

  final String path;
}
