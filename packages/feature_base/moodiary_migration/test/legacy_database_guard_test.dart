import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_lint/testing.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:path/path.dart' as p;

class _Diaries extends Fake implements DiaryRepository {
  final files = <String>{};

  @override
  Future<ReferencedMedia> collectReferencedMedia() async => (
    images: <String>{},
    audios: <String>{},
    videos: <String>{},
    files: files,
  );
}

class _Fonts extends Fake implements FontRepository {
  bool fail = false;
  final registered = <String>{};

  @override
  Future<void> insertFont(Font font) async {
    if (fail) throw StateError('insert failed');
    registered.add(font.fontFileName);
  }
}

void main() {
  late Directory support;
  late _Diaries diaries;
  late _Fonts fonts;
  late MemoryKVStorage kv;
  File file(String path) => File('${support.path}/$path');
  Directory directory(String path) => Directory('${support.path}/$path');
  const database = 'database/default.isar';
  const media = ['image', 'audio', 'video'];
  void seed() {
    for (final path in [
      database,
      '$database.lock',
      for (final name in media) '$name/旧文件',
    ]) {
      file(path).writeAsStringSync(path);
    }
    File('$repoRoot/packages/foundation/mui/assets/fonts/qweather-icons.ttf')
        .copySync(file('font/old.ttf').path);
  }

  setUpAll(() {
    support = Directory.systemTemp.createTempSync('legacy-guard-');
    PlatformService.get().applicationSupportPath = support.path;
  });
  tearDownAll(() => support.deleteSync(recursive: true));
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await AppFiles.initCreateDir();
    getIt.registerSingleton<IKVStorage>(kv = MemoryKVStorage());
    getIt.registerSingleton<DiaryRepository>(diaries = _Diaries());
    getIt.registerSingleton<FontRepository>(fonts = _Fonts());
    MoodiaryKVs.appVersion.set('2.7.3+73');
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await getIt.reset();
    for (final child in support.listSync()) {
      child.deleteSync(recursive: true);
    }
  });

  test('probe preserves the source version and ignores empty or finalized databases', () async {
    expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.none);
    file(database).createSync();
    expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.none);
    seed();
    expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.pending);
    expect(LegacyDatabaseGuard.sourceVersion, '2.7.3+73');
    expect(file(database).readAsStringSync(), database);
    MoodiaryKVs.dbEngineMigrated.set(true);
    expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.none);
    MoodiaryKVs.legacyAbandonJournal.set('interrupted');
    expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.abandoning);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.none);
  });

  test(
    'a failed KV read keeps the gate closed until a successful probe',
    () async {
      kv.data[MoodiaryKVs.appVersion.name] = 1;
      expect(
        await LegacyDatabaseGuard.probe(),
        LegacyDatabaseState.probeFailed,
      );
      MoodiaryKVs.appVersion.set('2.7.3');
      seed();
      expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.pending);
    },
  );

  test('an unreadable database path keeps the gate closed', () async {
    directory(database).createSync();
    expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.probeFailed);
    await expectLater(LegacyDatabaseGuard.abandon(), throwsStateError);
    expect(MoodiaryKVs.legacyAbandonJournal.get(), isNull);
    MoodiaryKVs.dbEngineMigrated.set(true);
    expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.none);
  });

  for (var moved = 0; moved <= 5; moved++) {
    test(
      'resumes after $moved moves and preserves every original file',
      () async {
        seed();
        final target = directory('$legacyAbandonedDirName/20261124-120000')
          ..createSync(recursive: true);
        MoodiaryKVs.legacyAbandonJournal.set(target.path);
        final entries = <FileSystemEntity>[
          for (final name in media) directory(name),
          file(database),
          file('$database.lock'),
        ];
        for (final entry in entries.take(moved)) {
          entry.renameSync(p.join(target.path, p.basename(entry.path)));
        }
        await AppFiles.initCreateDir();
        await LegacyDatabaseGuard.abandon();
        expect(LegacyDatabaseGuard.state, LegacyDatabaseState.none);
        for (final name in media) {
          expect(
            File('${target.path}/$name/旧文件').readAsStringSync(),
            '$name/旧文件',
          );
          expect(file('$name/旧文件').existsSync(), isFalse);
        }
        expect(directory('image/thumb').existsSync(), isTrue);
        expect(
          File('${target.path}/default.isar').readAsStringSync(),
          database,
        );
        expect(
          File('${target.path}/default.isar.lock').readAsStringSync(),
          '$database.lock',
        );
        expect(file('font/old.ttf').existsSync(), isTrue);
        expect(fonts.registered, {'qweather-icons.ttf'});
        expect(MoodiaryKVs.dbEngineMigrated.get(), isTrue);
        expect(MoodiaryKVs.searchIndexBackfilled.get(), isTrue);
        expect(MoodiaryKVs.legacyAbandonJournal.get(), isNull);
        expect(MoodiaryKVs.appVersion.get(), '2.7.3+73');
      },
    );
  }

  for (final backfilled in [false, true]) {
    test(
      'finishes journal after writing completion flags ($backfilled)',
      () async {
        seed();
        final target = directory('$legacyAbandonedDirName/20261124-120000')
          ..createSync(recursive: true);
        for (final entry in <FileSystemEntity>[
          for (final name in media) directory(name),
          file(database),
          file('$database.lock'),
        ]) {
          entry.renameSync(p.join(target.path, p.basename(entry.path)));
        }
        await AppFiles.initCreateDir();
        MoodiaryKVs.legacyAbandonJournal.set(target.path);
        MoodiaryKVs.dbEngineMigrated.set(true);
        MoodiaryKVs.searchIndexBackfilled.set(backfilled);
        await LegacyDatabaseGuard.abandon();
        expect(MoodiaryKVs.legacyAbandonJournal.get(), isNull);
        expect(MoodiaryKVs.searchIndexBackfilled.get(), isTrue);
        expect(
          file('$legacyAbandonedDirName/20261124-120000/default.isar')
              .readAsStringSync(),
          database,
        );
      },
    );
  }

  test('abandon preserves a chat image when SQLite has no diaries', () async {
    seed();
    final db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await getIt.unregister<DiaryRepository>();
    getIt.registerSingleton<DiaryRepository>(DiaryRepository(db));
    await db
        .into(db.chatSessions)
        .insert(
          ChatSessionsCompanion.insert(
            id: 'session',
            providerId: 'provider',
            model: 'model',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            id: 'message',
            sessionId: 'session',
            role: 'user',
            content: '',
            createdAt: 0,
            imageName: const Value('chat.jpg'),
          ),
        );
    file('image/chat.jpg').writeAsStringSync('chat image');

    await LegacyDatabaseGuard.abandon();

    expect(file('image/chat.jpg').readAsStringSync(), 'chat image');
    for (final name in media) {
      expect(file('$name/旧文件').readAsStringSync(), '$name/旧文件');
    }
    expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.none);
  });

  for (final resume in [false, true]) {
    test(
      'abandon finalizes despite unreadable fonts (existing journal: $resume)',
      () async {
        seed();
        final db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await getIt.unregister<FontRepository>();
        final repository = FontRepository(db);
        getIt.registerSingleton<FontRepository>(repository);
        final assets = '$repoRoot/packages/foundation/mui/assets/fonts';
        final bytes = await File('$assets/Dosis.ttf').readAsBytes();
        final truncated = bytes.sublist(0, 6);
        await file('font/old.ttf').writeAsBytes(truncated);
        final tables = ByteData.sublistView(bytes);
        final records = Iterable.generate(
          tables.getUint16(4),
          (index) => 12 + index * 16,
        );
        final axis = records.singleWhere(
          (offset) => String.fromCharCodes(bytes, offset, offset + 4) == 'fvar',
        );
        tables.setUint32(axis + 8, bytes.length - 1);
        await file('font/broken-axis.ttf').writeAsBytes(bytes);
        await File('$assets/qweather-icons.ttf')
            .copy(file('font/valid.ttf').path);
        if (resume) {
          final target = directory('$legacyAbandonedDirName/20261124-120000')
            ..createSync(recursive: true);
          MoodiaryKVs.legacyAbandonJournal.set(target.path);
          file(database).renameSync('${target.path}/default.isar');
        }

        await LegacyDatabaseGuard.abandon();

        // 坏字体让扫描整体失败时，字体登记被跳过，但放弃必须完成且字体文件原样保留。
        expect(file('font/valid.ttf').existsSync(), isTrue);
        expect(file('font/old.ttf').readAsBytesSync(), truncated);
        expect(file('font/broken-axis.ttf').readAsBytesSync(), bytes);
        expect(MoodiaryKVs.dbEngineMigrated.get(), isTrue);
        expect(MoodiaryKVs.searchIndexBackfilled.get(), isTrue);
        expect(MoodiaryKVs.legacyAbandonJournal.get(), isNull);
        expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.none);
      },
    );
  }

  test(
    'retry finishes a failed abandonment while preserving active SQLite media',
    () async {
      seed();
      diaries.files.add('attachment.pdf');
      fonts.fail = true;
      await expectLater(LegacyDatabaseGuard.abandon(), throwsStateError);
      expect(LegacyDatabaseGuard.state, LegacyDatabaseState.abandoning);
      final journal = MoodiaryKVs.legacyAbandonJournal.get()!;
      expect(File('$journal/default.isar').existsSync(), isTrue);
      expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.abandoning);
      fonts.fail = false;
      await Future.wait([
        LegacyDatabaseGuard.abandon(),
        LegacyDatabaseGuard.abandon(),
      ]);
      for (final name in media) {
        expect(file('$name/旧文件').readAsStringSync(), '$name/旧文件');
      }
      expect(await LegacyDatabaseGuard.probe(), LegacyDatabaseState.none);
    },
  );
}
