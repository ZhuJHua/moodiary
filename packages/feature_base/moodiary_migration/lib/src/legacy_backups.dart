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
    if (!dbEngineMigrated ||
        (MoodiaryKVs.legacyAbandonJournal.get()?.isNotEmpty ?? false)) {
      return 0;
    }
    var freed = 0;
    Future<void> removeFile(File file) async {
      if (filePaths != null && !filePaths.contains(file.path)) return;
      try {
        final bytes = await file.length();
        await file.delete();
        freed += bytes;
      } on PathNotFoundException {
        // Already removed by another cleanup.
      }
    }

    for (final name in legacyDatabaseBackupNames) {
      await removeFile(File(p.join(databasePath, name)));
    }
    Future<void> cleanDirectory(Directory directory) async {
      try {
        await for (final entry in directory.list(followLinks: false)) {
          if (entry is File) await removeFile(entry);
          if (entry is Directory) await cleanDirectory(entry);
        }
        if (await directory.list().isEmpty) await directory.delete();
      } on PathNotFoundException {
        return;
      }
    }

    final abandoned = p.join(p.dirname(databasePath), legacyAbandonedDirName);
    if (await FileSystemEntity.type(abandoned, followLinks: false) ==
        FileSystemEntityType.directory) {
      await cleanDirectory(Directory(abandoned));
    }
    return freed;
  }
}
