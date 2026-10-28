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

  test('snapshot cleanup keeps a backup absent from that snapshot', () async {
    MoodiaryKVs.dbEngineMigrated.set(true);
    final path = '${root.path}/default.isar.pre-sqlite.bak';
    expect(
      await LegacyBackups(databasePath: root.path).delete(filePaths: {path}),
      4,
    );
    expect(File(path).existsSync(), isFalse);
    expect(File('${root.path}/default.isar.v273bak').existsSync(), isTrue);
  });

  test(
    'unfinalized migration never exposes or deletes rollback files',
    () async {
      final backups = LegacyBackups(databasePath: root.path);
      expect(backups.dbEngineMigrated, isFalse);
      MoodiaryKVs.dbEngineMigrated.set(false);
      await backups.delete();
      expect(root.listSync().length, 3);
      MoodiaryKVs.dbEngineMigrated.set(true);
      expect(backups.dbEngineMigrated, isTrue);
      expect(await backups.delete(), 8);
      expect(await backups.delete(), 0);
      expect(root.listSync().single.path, endsWith('diary.sqlite'));
    },
  );
}
