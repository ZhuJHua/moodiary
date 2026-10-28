import 'dart:io';
import 'dart:isolate';

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

  Future<List<File>> scan() async {
    if (MoodiaryKVs.dbEngineMigrated.get() != true) return [];
    final path = databasePath;
    return Isolate.run(
      () => [
        for (final name in legacyDatabaseBackupNames)
          if (File(p.join(path, name)).existsSync()) File(p.join(path, name)),
      ],
    );
  }

  Future<int> delete() async {
    var freed = 0;
    for (final file in await scan()) {
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
