import 'dart:io';

import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:path/path.dart' as p;

/// Only finalized engine migrations make these rollback copies disposable.
/// Editor backups are owned by EditorMigrationService in a higher layer;
/// that service already purges them once its own migration is complete.
class LegacyBackups {
  final String databasePath;
  LegacyBackups({String? databasePath})
    : databasePath = databasePath ?? AppFiles.getRealPath('database', '');

  bool get dbEngineMigrated => MoodiaryKVs.dbEngineMigrated.get() == true;

  Future<int> delete({Set<String>? filePaths}) async {
    if (!dbEngineMigrated) return 0;
    var freed = 0;
    for (final name in legacyDatabaseBackupNames) {
      final file = File(p.join(databasePath, name));
      if (filePaths != null && !filePaths.contains(file.path)) continue;
      try {
        final bytes = await file.length();
        await file.delete();
        freed += bytes;
      } on PathNotFoundException {
        // Already removed by another cleanup.
      }
    }
    return freed;
  }
}
