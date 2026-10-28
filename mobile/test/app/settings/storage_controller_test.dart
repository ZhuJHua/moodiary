import 'dart:async';
import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_mobile/app/settings/storage/storage_controller.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/moodiary_sync.dart';

class _Runner implements SyncRunner {
  @override
  final ValueNotifier<SyncStatus> status = ValueNotifier(const SyncStatus());
  @override
  bool get isRunning => status.value.isRunning;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SyncController extends SyncController {
  @override
  SyncState build() => const SyncState.idle();

  void running(bool value) => state = value
      ? const SyncState.syncing(label: 'test')
      : const SyncState.idle();
}

class _DiaryRepository implements DiaryRepository {
  final referencedFiles = <String>{};

  @override
  Future<
    ({
      Set<String> images,
      Set<String> audios,
      Set<String> videos,
      Set<String> files,
    })
  >
  collectReferencedMedia() async => (
    images: <String>{},
    audios: <String>{},
    videos: <String>{},
    files: referencedFiles,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StorageScanProgress _progress({int cache = 0}) => StorageScanProgress(
  bytes: {StorageArea.cache: cache},
  done: StorageArea.values.toSet(),
  area: .other,
  files: 1,
  reclaimableCacheBytes: cache,
);

StorageOrphanMedia _noOrphans() =>
    StorageOrphanMedia(report: const MediaCleanupReport(paths: [], bytes: 0));

void _listen(ProviderContainer container) {
  container.listen(storageReclaimablesProvider, (_, _) {});
  container.listen(storageSelectionProvider, (_, _) {});
}

void main() {
  tearDown(getIt.reset);

  test(
    'running sync disables cache; clean skips it; idle re-enables it',
    () async {
      final runner = _Runner();
      getIt.registerSingleton<SyncRunner>(runner);
      addTearDown(runner.status.dispose);
      runner.status.value = SyncStatus(
        running: SyncActivity(
          trigger: .manual,
          direction: .sync,
          startedAt: DateTime(2026),
          backendName: 'test',
        ),
      );
      final container = ProviderContainer.test(
        overrides: [
          storageUsageProvider.overrideWith(
            (ref) => Stream.value(_progress(cache: 123)),
          ),
          storageStrayModelsProvider.overrideWith((ref) async => []),
          storageOrphanMediaProvider.overrideWith((ref) async => _noOrphans()),
          storageLegacyBackupsProvider.overrideWith(
            (ref) async => StorageLegacyBackups(files: [], bytes: 0),
          ),
          syncControllerProvider.overrideWith(_SyncController.new),
        ],
      );
      _listen(container);
      await pumpEventQueue();
      await container.pump();
      Reclaimable cache() => container.read(storageReclaimablesProvider).single;
      List<Reclaimable> selected() => container
          .read(storageSelectionProvider)
          .selected(container.read(storageReclaimablesProvider));
      expect(cache().busy, isTrue);
      expect(selected(), isEmpty);
      expect(
        await container.read(storageSelectionProvider.notifier).clean(),
        0,
      );
      await pumpEventQueue();
      await container.pump();
      expect(container.read(storageSelectionProvider).cleaned, isEmpty);

      runner.status.value = const SyncStatus();
      expect(cache().busy, isFalse);
      expect(selected().single.bytes, 123);
      final controller =
          container.read(syncControllerProvider.notifier) as _SyncController;
      controller.running(true);
      expect(cache().available, isFalse);
      controller.running(false);
      expect(cache().available, isTrue);
    },
  );

  test('refresh reruns every source and restores selectable entries', () async {
    final calls = <String, int>{};
    void called(String name) =>
        calls.update(name, (n) => n + 1, ifAbsent: () => 1);
    var models = Completer<List<StrayModelFile>>();
    var orphans = Completer<StorageOrphanMedia>();
    var legacy = Completer<StorageLegacyBackups>();
    final container = ProviderContainer.test(
      overrides: [
        storageUsageProvider.overrideWith((ref) {
          called('usage');
          return Stream.value(_progress(cache: 10));
        }),
        storageStrayModelsProvider.overrideWith((ref) {
          called('models');
          return models.future;
        }),
        storageOrphanMediaProvider.overrideWith((ref) {
          called('orphans');
          return orphans.future;
        }),
        storageLegacyBackupsProvider.overrideWith((ref) {
          called('legacy');
          return legacy.future;
        }),
        storageSyncBusyProvider.overrideWith((ref) => false),
      ],
    );
    _listen(container);
    void complete() {
      models.complete(const [
        StrayModelFile(path: '/x.part', bytes: 40, kind: .partial),
      ]);
      orphans.complete(_noOrphans());
      legacy.complete(StorageLegacyBackups(files: [], bytes: 0));
    }

    complete();
    await pumpEventQueue();
    await container.pump();
    Reclaimable partial() => container
        .read(storageReclaimablesProvider)
        .singleWhere((i) => i.kind == .partial);
    expect(partial().available, isTrue);
    container.read(storageSelectionProvider.notifier).toggle('partial');

    models = Completer();
    orphans = Completer();
    legacy = Completer();
    refreshStorage(container.invalidate);
    await pumpEventQueue();
    await container.pump();
    expect(partial().status.isLoading, isTrue);
    expect(partial().available, isFalse);
    complete();
    await pumpEventQueue();
    await container.pump();
    expect(calls, {'usage': 2, 'models': 2, 'orphans': 2, 'legacy': 2});
    expect(partial().available, isTrue);
    expect(
      container.read(storageSelectionProvider).checked,
      isNot(contains('partial')),
    );
    expect(
      container
          .read(storageReclaimablesProvider)
          .any((i) => i.status.isLoading),
      isFalse,
    );
  });

  test(
    'an invalidated source cannot replace fresh results with stale data',
    () async {
      final old = Completer<List<StrayModelFile>>();
      var models = old;
      final container = ProviderContainer.test(
        overrides: [
          storageUsageProvider.overrideWith((ref) => Stream.value(_progress())),
          storageStrayModelsProvider.overrideWith((ref) => models.future),
          storageOrphanMediaProvider.overrideWith((ref) async => _noOrphans()),
          storageLegacyBackupsProvider.overrideWith(
            (ref) async => StorageLegacyBackups(files: [], bytes: 0),
          ),
          storageSyncBusyProvider.overrideWith((ref) => false),
        ],
      );
      _listen(container);
      models = Completer();
      refreshStorage(container.invalidate);
      await pumpEventQueue();
      await container.pump();
      models.complete(const [
        StrayModelFile(path: '/new.part', bytes: 20, kind: .partial),
      ]);
      await pumpEventQueue();
      await container.pump();
      old.complete(const [
        StrayModelFile(path: '/old.part', bytes: 99, kind: .partial),
      ]);
      await pumpEventQueue();
      await container.pump();
      expect(container.read(storageReclaimablesProvider).single.bytes, 20);
    },
  );

  test(
    'safe-only clean deletes selected models and returns actual freed bytes',
    () async {
      final root = Directory.systemTemp.createTempSync('storage-selection-');
      addTearDown(() => root.deleteSync(recursive: true));
      final file = File('${root.path}/model.part')
        ..writeAsBytesSync(List.filled(40, 0));
      final container = ProviderContainer.test(
        overrides: [
          storageUsageProvider.overrideWith((ref) => Stream.value(_progress())),
          storageStrayModelsProvider.overrideWith(
            (ref) async => [
              if (file.existsSync())
                StrayModelFile(path: file.path, bytes: 50, kind: .partial),
            ],
          ),
          storageOrphanMediaProvider.overrideWith((ref) async => _noOrphans()),
          storageLegacyBackupsProvider.overrideWith(
            (ref) async => StorageLegacyBackups(files: [], bytes: 0),
          ),
          storageSyncBusyProvider.overrideWith((ref) => false),
        ],
      );
      _listen(container);
      await pumpEventQueue();
      await container.pump();
      expect(
        await container.read(storageSelectionProvider.notifier).clean(),
        40,
      );
      expect(file.existsSync(), isFalse);
      final state = container.read(storageSelectionProvider);
      expect(state.cleaned, {'partial'});
      expect(state.checked, isNot(contains('partial')));
      expect(state.cleaning, isFalse);
      await pumpEventQueue();
      await container.pump();
      expect(container.read(storageReclaimablesProvider), isEmpty);
    },
  );

  test('orphan clean rechecks references and only deletes displayed candidates', () async {
    final root = Directory.systemTemp.createTempSync('storage-orphans-');
    addTearDown(() => root.deleteSync(recursive: true));
    PlatformService.get().applicationSupportPath = root.path;
    FastImageRuntime.configure(
      imageDir: '${root.path}/image',
      thumbDir: '${root.path}/image/thumb',
    );
    final files = Directory('${root.path}/file')..createSync();
    final unused = File('${files.path}/unused.txt')
      ..writeAsBytesSync(List.filled(5, 0));
    final newlyUsed = File('${files.path}/used.txt')
      ..writeAsBytesSync(List.filled(7, 0));
    final repository = _DiaryRepository();
    getIt.registerSingleton<DiaryRepository>(repository);
    final container = ProviderContainer.test(
      overrides: [
        storageUsageProvider.overrideWith((ref) => Stream.value(_progress())),
        storageStrayModelsProvider.overrideWith((ref) async => []),
        storageLegacyBackupsProvider.overrideWith(
          (ref) async => StorageLegacyBackups(files: [], bytes: 0),
        ),
        storageSyncBusyProvider.overrideWith((ref) => false),
      ],
    );
    _listen(container);
    final scanned = await container.read(storageOrphanMediaProvider.future);
    expect(scanned.report.bytes, 12);
    expect(scanned.counts, {MediaType.file: 2});
    expect(scanned.areaBytes, {StorageArea.file: 12});

    repository.referencedFiles.add('used.txt');
    final unconfirmed = File('${files.path}/new.txt')
      ..writeAsBytesSync(List.filled(11, 0));
    container.read(storageSelectionProvider.notifier).toggle('orphan');
    expect(await container.read(storageSelectionProvider.notifier).clean(), 5);
    expect(unused.existsSync(), isFalse);
    expect(newlyUsed.existsSync(), isTrue);
    expect(unconfirmed.existsSync(), isTrue);
    // Let the post-clean scan finish before its temporary directory is removed.
    await container.read(storageOrphanMediaProvider.future);
  });

  test('a failed source keeps its entries disabled until refreshed', () async {
    var fail = true;
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        storageUsageProvider.overrideWith((ref) => Stream.value(_progress())),
        storageStrayModelsProvider.overrideWith((ref) async {
          if (fail) throw StateError('scan failed');
          return const [
            StrayModelFile(path: '/x.part', bytes: 40, kind: .partial),
          ];
        }),
        storageOrphanMediaProvider.overrideWith((ref) async => _noOrphans()),
        storageLegacyBackupsProvider.overrideWith(
          (ref) async => StorageLegacyBackups(files: [], bytes: 0),
        ),
        storageSyncBusyProvider.overrideWith((ref) => false),
      ],
    );
    _listen(container);
    await pumpEventQueue();
    await container.pump();
    expect(container.read(storageReclaimablesProvider), hasLength(3));
    expect(
      container
          .read(storageReclaimablesProvider)
          .every((i) => i.status.hasError && !i.available),
      isTrue,
    );
    fail = false;
    refreshStorage(container.invalidate);
    await pumpEventQueue();
    await container.pump();
    expect(
      container.read(storageReclaimablesProvider).single.available,
      isTrue,
    );
  });
}
