import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_mobile/app/di/bootstrap.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Directories extends PathProviderPlatform {
  _Directories(this.root);
  final Directory root;

  @override
  Future<String> getApplicationSupportPath() async => '${root.path}/support';

  @override
  Future<String> getApplicationCachePath() async => '${root.path}/cache';
}

class _Database extends Fake implements MoodiaryDatabase {
  int clearCalls = 0;
  int closeCalls = 0;
  bool failClear = false;
  bool failClose = false;

  @override
  Future<void> clearAll() async {
    clearCalls++;
    if (failClear) throw StateError('disk full');
  }

  @override
  Future<void> close() async {
    closeCalls++;
    if (failClose) throw StateError('close failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late ProviderContainer platformContainer;
  late Ref ref;
  late _Database database;
  late List<File> files;
  late int openCallCount;
  late int secureDeleteAllCalls;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('mobile-reset-');
    addTearDown(() => root.delete(recursive: true));
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Directories(root);
    addTearDown(() => PathProviderPlatform.instance = previous);
    platformContainer = ProviderContainer.test(retry: (_, _) => null);
  });

  setUp(() {
    final preferences = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = preferences);
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.moodiary_native.ReminderNotificationsApi.clear',
      ReminderNotificationsApi.pigeonChannelCodec,
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler(channel, (_) async => [null]);
    addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
    secureDeleteAllCalls = 0;
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    messenger.setMockMethodCallHandler(secureChannel, (call) async {
      if (call.method == 'deleteAll') {
        secureDeleteAllCalls++;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(secureChannel, null));

    openCallCount = 0;
    database = _Database();
    final container = ProviderContainer.test(
      parent: platformContainer,
      retry: (_, _) => null,
      overrides: [
        moodiaryDatabaseAsyncProvider.overrideWith((ref) async {
          openCallCount++;
          return database;
        }),
      ],
    );
    ref = container.read(
      Provider<Ref>(
        (ref) => ref,
        dependencies: [moodiaryDatabaseAsyncProvider],
      ),
    );
    final directory = Directory('${root.path}/support/database')
      ..createSync(recursive: true);
    files = [
      for (final suffix in ['', '-wal', '-shm', '-journal'])
        File('${directory.path}/moodiary.db$suffix')
          ..writeAsStringSync('sentinel'),
    ];
  });

  test('reset before opening removes SQLite and sidecars without opening the database', () async {
    final mmkvDir = Directory('${root.path}/support/mmkv')
      ..createSync(recursive: true);
    final mmkvFile = File('${mmkvDir.path}/mmkv.default')
      ..writeAsStringSync('prefs');
    final unrelated = File('${files.first.parent.path}/keep.db')
      ..writeAsStringSync('keep');
    expect(ref.read(moodiaryDatabaseAsyncProvider.exists), isFalse);
    await resetAllData(ref);
    expect(ref.read(moodiaryDatabaseAsyncProvider.exists), isFalse);
    expect(openCallCount, 0);
    expect(database.clearCalls, 0);
    for (final file in files) {
      expect(file.existsSync(), isFalse, reason: file.path);
    }
    expect(mmkvFile.existsSync(), isFalse);
    expect(secureDeleteAllCalls, 1);
    expect(unrelated.readAsStringSync(), 'keep');
  });

  test('reset after opening clears the existing database in place', () async {
    expect(
      await ref.read(moodiaryDatabaseAsyncProvider.future),
      same(database),
    );
    await resetAllData(ref);
    expect(openCallCount, 1);
    expect(database.clearCalls, 1);
    for (final file in files) {
      expect(file.readAsStringSync(), 'sentinel', reason: file.path);
    }
  });

  test(
    'reset after failed database open removes files without reopening',
    () async {
      var failedOpens = 0;
      final container = ProviderContainer.test(
        parent: platformContainer,
        retry: (_, _) => null,
        overrides: [
          moodiaryDatabaseAsyncProvider.overrideWith((ref) async {
            failedOpens++;
            throw StateError('corrupt db');
          }),
        ],
      );
      final failedRef = container.read(
        Provider<Ref>(
          (ref) => ref,
          dependencies: [moodiaryDatabaseAsyncProvider],
        ),
      );
      await expectLater(
        failedRef.read(moodiaryDatabaseAsyncProvider.future),
        throwsStateError,
      );
      expect(failedOpens, 1);
      await resetAllData(failedRef);
      expect(failedOpens, 1);
      for (final file in files) {
        expect(file.existsSync(), isFalse, reason: file.path);
      }
    },
  );

  test(
    'reset closes and deletes files when clearAll fails on an open database',
    () async {
      final secure = MemorySecureKVStorage()..data['password'] = 'pin-hash';
      SecureKVStore.installForTesting(secure);
      addTearDown(SecureKVStore.resetForTesting);
      database.failClear = true;
      await ref.read(moodiaryDatabaseAsyncProvider.future);
      await resetAllData(ref);
      expect(database.clearCalls, 1);
      expect(database.closeCalls, 1);
      for (final file in files) {
        expect(file.existsSync(), isFalse, reason: file.path);
      }
      expect(secure.data, isEmpty);
    },
  );

  test(
    'reset preserves app lock when open database cannot be cleared or closed',
    () async {
      final kv = MemoryKVStorage()..set('theme', 'dark');
      final secure = MemorySecureKVStorage()..data['password'] = 'pin-hash';
      KVStore.installForTesting(kv);
      SecureKVStore.installForTesting(secure);
      addTearDown(() {
        SecureKVStore.resetForTesting();
        KVStore.resetForTesting();
      });
      database
        ..failClear = true
        ..failClose = true;
      await ref.read(moodiaryDatabaseAsyncProvider.future);
      await expectLater(resetAllData(ref), throwsStateError);
      expect(secure.data['password'], 'pin-hash');
      expect(kv.get<String>('theme'), 'dark');
      for (final file in files) {
        expect(file.existsSync(), isTrue, reason: file.path);
      }
    },
  );
}
