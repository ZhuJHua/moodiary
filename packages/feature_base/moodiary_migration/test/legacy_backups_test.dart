import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

void main() {
  late Directory root;
  late Directory support;
  setUp(() {
    support = Directory.systemTemp.createTempSync('legacy-backups-');
    root = Directory('${support.path}/database')..createSync();
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
    for (final name in [
      'default.isar.pre-sqlite.bak',
      'default.isar.v273bak',
      'diary.sqlite',
    ]) {
      File('${root.path}/$name').writeAsStringSync('data');
    }
  });
  tearDown(() async {
    support.deleteSync(recursive: true);
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

  test('quarantine cleanup honors the journal and the file snapshot', () async {
    final quarantine = Directory('${support.path}/$legacyAbandonedDirName');
    final image = Directory('${quarantine.path}/20261124-120000/image')
      ..createSync(recursive: true);
    final first = File('${image.path}/first')..writeAsStringSync('123');
    final second = File('${image.path}/second')..writeAsStringSync('45678');
    final backups = LegacyBackups(databasePath: root.path);
    MoodiaryKVs.dbEngineMigrated.set(true);
    MoodiaryKVs.legacyAbandonJournal.set(image.parent.path);
    expect(await backups.delete(), 0);
    MoodiaryKVs.legacyAbandonJournal.remove();
    expect(await backups.delete(filePaths: {first.path}), 3);
    expect(first.existsSync(), isFalse);
    expect(second.existsSync(), isTrue);
    expect(await backups.delete(filePaths: {second.path}), 5);
    expect(quarantine.existsSync(), isFalse);
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
