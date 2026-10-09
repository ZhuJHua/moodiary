import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_data/src/db/db_encryption.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:sqlite3_simple/sqlite3_simple.dart';
import 'package:sqlite3_vec/sqlite3_vec.dart';

import 'drift/moodiary/generated/schema.dart';
import 'drift/moodiary/generated/schema_v1.dart' as v1;
import 'drift/moodiary/generated/schema_v2.dart' as v2;

String marked(String word) => '$searchHitStart$word$searchHitEnd';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    loadSimpleExtension();
    installJiebaDict();
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<int> userVersion(GeneratedDatabase db) async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    return row.data.values.first as int;
  }

  v1.DiariesCompanion v1Diary(
    String id, {
    double? lat,
    double? lon,
    String? placeName,
    int time = 0,
  }) => v1.DiariesCompanion.insert(
    id: id,
    title: '',
    content: '',
    contentText: '',
    time: time,
    lastModified: 0,
    show: 1,
    mood: 'neutral',
    type: 'tiptap',
    latitude: Value(lat),
    longitude: Value(lon),
    placeName: Value(placeName),
  );

  test('新库直接建到 v3，且与 v3 快照一致', () async {
    final db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    await verifier.migrateAndValidate(db, 3);
    expect(await userVersion(db), 3);
    await db.close();
  });

  test('v2 老库升级：旧行留空，预设被丢弃', () async {
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    await old
        .into(old.chatSessions)
        .insert(
          v2.ChatSessionsCompanion.insert(
            id: 's1',
            providerId: 'p1',
            model: 'm1',
            createdAt: 0,
            updatedAt: 0,
            agentPresetId: const Value('ap'),
            personaSnapshot: const Value('y'),
          ),
        );
    await old
        .into(old.chatMessages)
        .insert(
          v2.ChatMessagesCompanion.insert(
            id: 'm1',
            sessionId: 's1',
            role: 'user',
            content: 'hi',
            createdAt: 0,
          ),
        );
    await old
        .into(old.memories)
        .insert(
          v2.MemoriesCompanion.insert(
            id: 'f1',
            category: 'preference',
            content: 'call me 小竹',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await old
        .into(old.agentPresets)
        .insert(
          v2.AgentPresetsCompanion.insert(
            id: 'ap',
            name: 'x',
            persona: 'y',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await old.close();

    final db = MoodiaryDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    final message = await db
        .customSelect("SELECT provider_id FROM chat_messages WHERE id = 'm1'")
        .getSingle();
    expect(message.readNullable<String>('provider_id'), isNull);
    final fact = await db
        .customSelect("SELECT source FROM memories WHERE id = 'f1'")
        .getSingle();
    expect(fact.readNullable<String>('source'), isNull);
    final session = await db
        .customSelect("SELECT model FROM chat_sessions WHERE id = 's1'")
        .getSingle();
    expect(session.read<String>('model'), 'm1');
    await db.close();
  });

  test('v1 老库升级：位置快照归并成常用地点，日记改引用，一篇不丢', () async {
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old
        .into(old.categories)
        .insert(
          v1.CategoriesCompanion.insert(id: 'c1', name: '生活', lastModified: 0),
        );
    await old.batch((b) {
      b.insertAll(old.diaries, [
        v1Diary('d1', lat: 30.28, lon: 120.15, placeName: '杭州市 西湖区', time: 1),
        v1Diary('d2', lat: 30.29, lon: 120.16, placeName: '杭州市 西湖区', time: 2),
        v1Diary('d3', lat: 24.48, lon: 118.08, placeName: '', time: 3),
        v1Diary('d4', time: 4),
      ]);
    });
    await old.close();

    final db = MoodiaryDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    final places = await PlaceRepository(db).getAllPlaces();
    expect(places, hasLength(2));
    final xihu = places.singleWhere((p) => p.name == '杭州市 西湖区');
    expect(xihu.id, Place.idForName('杭州市 西湖区'), reason: 'id 由地名派生，跨设备一致');
    expect(xihu.latitude, 30.29, reason: '坐标取最近一篇');
    final byCoords = places.singleWhere((p) => p.name != '杭州市 西湖区');
    expect(byCoords.name, '24.4800, 118.0800');
    final repo = DiaryRepository(db);
    expect((await repo.getDiaryByBusinessId('d1'))!.placeId, xihu.id);
    expect((await repo.getDiaryByBusinessId('d2'))!.placeId, xihu.id);
    expect((await repo.getDiaryByBusinessId('d3'))!.placeId, byCoords.id);
    expect((await repo.getDiaryByBusinessId('d4'))!.placeId, isNull);
    expect(
      (await CategoryRepository(db).getCategoryById('c1'))?.categoryName,
      '生活',
    );
    await db.close();
  });

  test('v2 老库升级：索引换成 simple external content，老数据重建后可搜', () async {
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    await old
        .into(old.diaries)
        .insert(
          v2.DiariesCompanion.insert(
            id: 'd1',
            title: '关于苹果的日记',
            content: '',
            contentText: '早上吃了一个苹果，味道不错',
            time: 1,
            lastModified: 0,
            show: 1,
            mood: 'neutral',
            type: 'tiptap',
          ),
        );
    await old.close();

    final db = MoodiaryDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    final hit = (await DiaryRepository(db).searchDiaries(query: '苹果')).single;
    expect(hit.diary.id, 'd1', reason: "'rebuild' 从 diaries 重灌了整个索引");
    expect(hit.titleHighlight, '关于${marked('苹果')}的日记');
    await db.close();
  });

  group('逐档迁移', () {
    const versions = GeneratedHelper.versions;
    for (var i = 0; i + 1 < versions.length; i++) {
      final (from, to) = (versions[i], versions[i + 1]);
      test('v$from → v$to 落在下一档快照上', () async {
        final schema = await verifier.schemaAt(from);
        final db = MoodiaryDatabase.forTesting(schema.newConnection());
        await verifier.migrateAndValidate(db, to);
        await db.close();
      });
    }
  });

  group('静态加密', () {
    late Directory dir;
    late MemorySecureKVStorage secure;
    late MemoryKVStorage kv;

    setUp(() async {
      await getIt.reset();
      loadSqliteVec();
      secure = MemorySecureKVStorage();
      kv = MemoryKVStorage();
      getIt.registerSingleton<ISecureKVStorage>(secure);
      getIt.registerSingleton<IKVStorage>(kv);
      dir = Directory.systemTemp.createTempSync('db_enc');
    });

    tearDown(() async {
      await getIt.reset();
      dir.deleteSync(recursive: true);
    });

    String? storedKey() => secure.data[MoodiarySecureKVs.databaseKey.name];

    Diary diary(String id, String text) => Diary(
      id: id,
      title: 'title-$id',
      content: '{"type":"doc","content":[]}',
      contentText: text,
      time: DateTime.utc(2026, 1, 1),
      lastModified: DateTime.utc(2026, 1, 1),
      show: true,
      mood: .neutral,
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: const [],
      type: 'tiptap',
    );

    Uint8List f32(List<double> v) =>
        Float32List.fromList(v).buffer.asUint8List();

    Future<String> plaintextDatabase() async {
      final path = '${dir.path}/moodiary.db';
      // 线上的明文库都是 WAL 模式，文件头里带着这个标记
      final db = MoodiaryDatabase.forTesting(
        NativeDatabase(
          File(path),
          setup: (raw) => raw.execute('PRAGMA journal_mode = WAL'),
        ),
      );
      await DiaryRepository(db)
          .insertDiaries([diary('d1', '今天吃了苹果'), diary('d2', '香蕉也不错')]);
      await db.customStatement(
        'CREATE VIRTUAL TABLE vec_diary_chunks '
        'USING vec0(embedding float[4] distance_metric=cosine)',
      );
      await db.customStatement(
        'INSERT INTO vec_diary_chunks(rowid, embedding) VALUES (1, ?)',
        [
          f32([1, 0, 0, 0]),
        ],
      );
      await db.close();
      expect(databaseFileState(path), DatabaseFileState.plaintext);
      return path;
    }

    Future<MoodiaryDatabase> open(String path) =>
        MoodiaryDatabase.open(path: path, jiebaDictDir: defaultJiebaDictDir());

    Future<List<String>> search(MoodiaryDatabase db, String q) async => [
      for (final hit in await DiaryRepository(db).searchDiaries(query: q))
        hit.diary.id,
    ];

    Future<int> vecHit(MoodiaryDatabase db) async {
      final rows = await db
          .customSelect(
            'SELECT rowid FROM vec_diary_chunks WHERE embedding MATCH ? '
            'AND k = 1',
            variables: [
              Variable(f32([1, 0, 0, 0])),
            ],
          )
          .get();
      return rows.single.read<int>('rowid');
    }

    test('宿主构建必须是 SQLCipher，否则 PRAGMA key 会被静默忽略', () {
      final db = sqlite3.sqlite3.openInMemory();
      addTearDown(db.close);
      expect(db.select('PRAGMA cipher_version'), isNotEmpty);
    });

    test('按文件头分类：不足 16 字节算不存在', () {
      final path = '${dir.path}/x.db';
      expect(databaseFileState(path), DatabaseFileState.missing);
      File(path).writeAsBytesSync([]);
      expect(databaseFileState(path), DatabaseFileState.missing);
      File(path).writeAsBytesSync(List.filled(8, 1));
      expect(databaseFileState(path), DatabaseFileState.missing);
      File(path).writeAsBytesSync(List.filled(4096, 0x5a));
      expect(databaseFileState(path), DatabaseFileState.encrypted);
      File(path).deleteSync();
      sqlite3.sqlite3.open(path)
        ..execute('CREATE TABLE t(x)')
        ..close();
      expect(databaseFileState(path), DatabaseFileState.plaintext);
    });

    test('密钥解析：首次生成是 fresh，读回才是 stored，加密库缺密钥是 lost', () async {
      final first = await resolveDatabaseKey(fileState: .missing);
      expect(first, isA<DatabaseKeyFresh>());
      expect(storedKey(), hasLength(64));

      final second = await resolveDatabaseKey(fileState: .plaintext);
      expect(second, isA<DatabaseKeyStored>());
      expect((second as DatabaseKeyStored).key, storedKey());

      secure.data.clear();
      await expectLater(
        resolveDatabaseKey(fileState: .encrypted),
        throwsA(isA<DatabaseKeyLost>()),
      );

      secure.data[MoodiarySecureKVs.databaseKey.name] = 'not-a-key';
      expect(
        await resolveDatabaseKey(fileState: .encrypted),
        isA<DatabaseKeyFailed>(),
      );
      expect(
        await resolveDatabaseKey(fileState: .plaintext),
        isA<DatabaseKeyFresh>(),
        reason: '没有加密数据依赖坏掉的值，直接换一把',
      );
      expect(storedKey(), hasLength(64));

      secure.data.clear();
      secure.failingReads.add(MoodiarySecureKVs.databaseKey.name);
      expect(
        await resolveDatabaseKey(fileState: .plaintext),
        isA<DatabaseKeyFailed>(),
      );
    });

    test('明文库 + 读回的密钥：加密后拼音搜索、vec0、触发器照常，重开仍可读', () async {
      final path = await plaintextDatabase();
      secure.data[MoodiarySecureKVs.databaseKey.name] = newDatabaseKey();
      File('$path$encryptingSuffix').writeAsStringSync('stale half copy');

      var db = await open(path);
      expect(databaseFileState(path), DatabaseFileState.encrypted);
      expect(File('$path$encryptingSuffix').existsSync(), isFalse);
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, 3);
      expect(await search(db, 'pingguo'), ['d1']);
      expect(await vecHit(db), 1);
      await DiaryRepository(db).insertDiaries([diary('d3', '橙子很甜')]);
      expect(await search(db, 'chengzi'), ['d3']);
      await db.close();

      db = await open(path);
      expect(await search(db, 'xiangjiao'), ['d2']);
      await db.close();

      final wrong = sqlite3.sqlite3.open(path);
      addTearDown(wrong.close);
      expect(
        () => wrong.select('SELECT count(*) FROM diaries'),
        throwsA(isA<sqlite3.SqliteException>()),
      );
    });

    test('当次生成的密钥不加密已有明文库，下一次启动读回后才加密', () async {
      final path = await plaintextDatabase();

      var db = await open(path);
      expect(storedKey(), hasLength(64));
      expect(databaseFileState(path), DatabaseFileState.plaintext);
      expect(await search(db, 'pingguo'), ['d1']);
      await db.close();

      db = await open(path);
      expect(databaseFileState(path), DatabaseFileState.encrypted);
      expect(await search(db, 'pingguo'), ['d1']);
      await db.close();
    });

    test('新库也先明文，下一次启动用读回的密钥加密', () async {
      final path = '${dir.path}/moodiary.db';
      var db = await open(path);
      await DiaryRepository(db).insertDiaries([diary('d1', '今天吃了苹果')]);
      await db.close();
      expect(storedKey(), hasLength(64));
      expect(databaseFileState(path), DatabaseFileState.plaintext);

      db = await open(path);
      await db.close();
      expect(databaseFileState(path), DatabaseFileState.encrypted);

      final raw = sqlite3.sqlite3.open(path);
      addTearDown(raw.close);
      applyDatabaseKey(raw, storedKey()!);
      expect(raw.select('SELECT count(*) AS n FROM diaries').single['n'], 1);
    });

    test('校验失败：副本与旁文件清掉，原文件不动，下次重来能成功', () async {
      final path = await plaintextDatabase();
      final key = newDatabaseKey();

      afterExportForTesting = (tmp) =>
          File(tmp).writeAsBytesSync(List.filled(8192, 0));
      addTearDown(() => afterExportForTesting = null);
      await expectLater(
        encryptPlaintextDatabase(path: path, key: key),
        throwsA(anything),
      );
      // 只有 journal_mode 落回 DELETE 这一处头部改动，数据原样
      expect(databaseFileState(path), DatabaseFileState.plaintext);
      final raw = sqlite3.sqlite3.open(path);
      expect(raw.select('SELECT count(*) AS n FROM diaries').single['n'], 2);
      raw.close();
      for (final suffix in [
        encryptingSuffix,
        '$encryptingSuffix-journal',
        '-wal',
        '-shm',
        '-journal',
      ]) {
        expect(File('$path$suffix').existsSync(), isFalse, reason: suffix);
      }

      afterExportForTesting = null;
      await encryptPlaintextDatabase(path: path, key: key);
      expect(databaseFileState(path), DatabaseFileState.encrypted);
    });

    test('密钥读不到：明文库照常打开，加密库才是启动失败', () async {
      final path = await plaintextDatabase();
      secure.failingReads.add(MoodiarySecureKVs.databaseKey.name);
      final db = await open(path);
      expect(databaseFileState(path), DatabaseFileState.plaintext);
      expect(await search(db, 'pingguo'), ['d1']);
      await db.close();

      secure.failingReads.clear();
      secure.data[MoodiarySecureKVs.databaseKey.name] = newDatabaseKey();
      await (await open(path)).close();
      expect(databaseFileState(path), DatabaseFileState.encrypted);

      secure.failingReads.add(MoodiarySecureKVs.databaseKey.name);
      await expectLater(open(path), throwsA(isA<DatabaseKeyUnavailable>()));
    });

    test('密钥对不上：启动失败，文件不动', () async {
      final path = await plaintextDatabase();
      final key = newDatabaseKey();
      secure.data[MoodiarySecureKVs.databaseKey.name] = key;
      await (await open(path)).close();

      secure.data[MoodiarySecureKVs.databaseKey.name] = newDatabaseKey();
      await expectLater(open(path), throwsA(isA<DatabaseKeyMismatch>()));

      secure.data[MoodiarySecureKVs.databaseKey.name] = key;
      final db = await open(path);
      expect(await search(db, 'pingguo'), ['d1']);
      await db.close();
    });

    test('加密失败：错误文本不含密钥；按明文打开并计数，三次后不再尝试', () async {
      final path = await plaintextDatabase();
      final key = newDatabaseKey();
      secure.data[MoodiarySecureKVs.databaseKey.name] = key;

      // 目录只读 → ATTACH 建不出副本（root 不受权限约束，跳过这一段）
      final root =
          Process.runSync('id', ['-u']).stdout.toString().trim() == '0';
      if (!root) {
        await Process.run('chmod', ['0500', dir.path]);
        try {
          await expectLater(
            encryptPlaintextDatabase(path: path, key: key),
            throwsA(
              predicate(
                (e) => !e.toString().contains(key),
                'error without key',
              ),
            ),
          );
        } finally {
          await Process.run('chmod', ['0700', dir.path]);
        }
        expect(File('$path$encryptingSuffix').existsSync(), isFalse);
      }

      encryptImplementation = (_, _, {afterExport}) =>
          throw StateError('disk full');
      addTearDown(() => encryptImplementation = encryptDatabaseFile);
      var db = await open(path);
      expect(databaseFileState(path), DatabaseFileState.plaintext);
      expect(MoodiaryKVs.dbEncryptFailures.get(), 1);
      expect(await search(db, 'pingguo'), ['d1']);
      await db.close();

      MoodiaryKVs.dbEncryptFailures.set(maxEncryptFailures);
      db = await open(path);
      expect(databaseFileState(path), DatabaseFileState.plaintext);
      expect(MoodiaryKVs.dbEncryptFailures.get(), maxEncryptFailures);
      await db.close();

      encryptImplementation = encryptDatabaseFile;
      MoodiaryKVs.dbEncryptFailures.remove();
      db = await open(path);
      expect(databaseFileState(path), DatabaseFileState.encrypted);
      expect(MoodiaryKVs.dbEncryptFailures.get(), 0);
      await db.close();
    });

    test('WAL 里未检查点的改动也进加密副本，且不留明文旁文件', () async {
      final live = await plaintextDatabase();
      final copy = '${dir.path}/copy.db';
      final writer = sqlite3.sqlite3.open(live);
      writer.execute("UPDATE diaries SET title = 'wal-title' WHERE id = 'd1'");
      expect(File('$live-wal').lengthSync(), greaterThan(0));
      File(live).copySync(copy);
      File('$live-wal').copySync('$copy-wal');
      File('$live-shm').copySync('$copy-shm');
      writer.close();

      final key = newDatabaseKey();
      await encryptPlaintextDatabase(path: copy, key: key);
      for (final suffix in ['-wal', '-shm', '-journal']) {
        expect(File('$copy$suffix').existsSync(), isFalse, reason: suffix);
      }
      expect(databaseFileState(copy), DatabaseFileState.encrypted);

      secure.data[MoodiarySecureKVs.databaseKey.name] = key;
      final db = await open(copy);
      final row = await db
          .customSelect("SELECT title FROM diaries WHERE id = 'd1'")
          .getSingle();
      expect(row.read<String>('title'), 'wal-title');
      await db.close();
    });
  });
}
