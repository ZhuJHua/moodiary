import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

void main() {
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('legacy-backups-');
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    for (final name in [
      'default.isar.pre-sqlite.bak',
      'default.isar.v273bak',
      'diary.sqlite',
    ]) {
      File('${root.path}/$name').writeAsStringSync('data');
    }
  });
  tearDown(() async {
    root.deleteSync(recursive: true);
    await getIt.reset();
  });

  test(
    'unfinalized migration never exposes or deletes rollback files',
    () async {
      final backups = LegacyBackups(databasePath: root.path);
      expect(await backups.scan(), isEmpty);
      MoodiaryKVs.dbEngineMigrated.set(false);
      await backups.delete();
      expect(root.listSync().length, 3);
      MoodiaryKVs.dbEngineMigrated.set(true);
      expect((await backups.scan()).length, 2);
      await backups.delete();
      expect(root.listSync().single.path, endsWith('diary.sqlite'));
    },
  );
}
