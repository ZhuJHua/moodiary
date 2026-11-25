import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';

import '../sync_test_harness.dart';

class _Storage extends IKVStorage {
  int reads = 0;
  @override
  Future<void> init() async {}
  @override
  T? get<T extends Object>(String key) {
    if (key == MoodiaryKVs.syncPollInterval.name) reads++;
    return null;
  }
}

class _Diary extends Fake implements DiaryRepository {
  @override
  Stream<DiaryEvent> get diaryEvents => const Stream.empty();
}

class _Tag extends Fake implements TagRepository {
  @override
  Stream<TagEvent> get tagEvents => const Stream.empty();
}

class _Category extends Fake implements CategoryRepository {
  @override
  Stream<CategoryEvent> get categoryEvents => const Stream.empty();
}

class _Place extends Fake implements PlaceRepository {
  @override
  Stream<PlaceEvent> get placeEvents => const Stream.empty();
}

AutoSyncWatcher _watcher(ProviderContainer container, Stream<bool> online) =>
    AutoSyncWatcher(
      container.read(syncOperationGuardProvider),
      container.read(syncControllerProvider.notifier),
      _Diary(),
      _Category(),
      _Tag(),
      _Place(),
      container.read(syncDirtyDiaryIdsProvider.notifier),
      container.read(openDiaryRegistryProvider),
      resolveBackend: () => container.read(activeSyncBackendProvider),
      configuredBackends: () =>
          container.read(configuredCloudBackendIdsProvider.future),
      isDirty: (id) => container.read(syncDirtyDiaryIdsProvider).contains(id),
      onlineChanges: () => online,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('starting twice registers only one interval listener', () async {
    final storage = _Storage();
    KVStore.installForTesting(storage);
    addTearDown(KVStore.resetForTesting);
    final container = ProviderContainer.test(retry: (_, _) => null);
    final watcher = _watcher(container, const Stream.empty());
    addTearDown(watcher.dispose);
    watcher.start();
    watcher.start();
    final before = storage.reads;
    MoodiaryKVs.syncPollInterval.set(90);
    expect(storage.reads - before, 1);
  });

  test('configuration excludes a network poll and manual sync', () async {
    final backend = FakeRemoteBackend();
    final env = await setUpSyncEnv(activeBackend: backend);
    addTearDown(tearDownSyncEnv);
    final online = StreamController<bool>.broadcast(sync: true);
    addTearDown(online.close);
    MoodiaryKVs.autoSync.set(true);
    final watcher = _watcher(env.container, online.stream);
    addTearDown(watcher.dispose);
    watcher.start();
    final settings = env.container.read(
      activeSyncProviderTypeProvider.notifier,
    );
    final writing = settings.clearOptions(.s3);
    expect(env.guard.isBusy, isTrue);
    online.add(true);
    final manual = env.container.read(syncControllerProvider.notifier).sync();
    expect(await manual, isNull);
    expect(await writing, isTrue);
    expect(backend.ops, isEmpty);
    expect(env.guard.isBusy, isFalse);
  });

  test('network poll excludes configuration through probe, sync and stat writeback', () async {
    final root = Directory.systemTemp.createTempSync('auto-sync-poll');
    addTearDown(() => root.deleteSync(recursive: true));
    PlatformService.get()
      ..applicationSupportPath = root.path
      ..applicationCachePath = root.path;
    final backend = FakeRemoteBackend();
    final env = await setUpSyncEnv(activeBackend: backend);
    addTearDown(tearDownSyncEnv);
    final online = StreamController<bool>.broadcast(sync: true);
    addTearDown(online.close);
    final settings = env.container.read(
      activeSyncProviderTypeProvider.notifier,
    );
    final attempts = <(String, bool)>[];
    backend.beforeOp = (op, key) {
      if (key == SyncKeys.manifestPath && (op == 'stat' || op == 'read')) {
        attempts.add((op, settings.select(.s3)));
      }
    };
    final stat = MoodiaryKVs.syncManifestStat.getNotifier();
    void onStat() => attempts.add(('writeback', settings.select(.s3)));
    stat.addListener(onStat);
    addTearDown(() => stat.removeListener(onStat));
    MoodiaryKVs.autoSync.set(true);
    final watcher = _watcher(env.container, online.stream);
    addTearDown(watcher.dispose);
    watcher.start();
    final finished = env.guard.changes.firstWhere((busy) => !busy);
    online.add(true);
    await finished;
    expect(attempts.first, ('stat', false));
    expect(attempts, contains(('read', false)));
    expect(attempts.last, ('writeback', false));
    expect(attempts.every((attempt) => !attempt.$2), isTrue);
    expect(stat.value, 'webdav|');
    expect(settings.select(.s3), isTrue);
  });
}
