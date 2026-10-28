import 'dart:async';
import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_mobile/app/settings/storage/storage_controller.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
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
  final images = <String>{};
  final videos = <String>{};
  final files = <String>{};

  @override
  Future<ReferencedMedia> collectReferencedMedia() async => (
    images: Set.of(images),
    audios: <String>{},
    videos: Set.of(videos),
    files: Set.of(files),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StorageReport _report({
  Map<StorageCleanupKind, List<StorageCandidate>> candidates = const {},
}) => StorageReport(
  bytes: const {},
  done: StorageArea.values.toSet(),
  area: .other,
  files: 1,
  candidates: candidates.map(
    (kind, files) => MapEntry(kind, StorageCandidates(files)),
  ),
);

const _partial = StorageCandidate(path: '/x.part', bytes: 40, area: .model);
const _cache = StorageCandidate(path: '/cache', bytes: 123, area: .cache);

void _listen(ProviderContainer container) {
  container.listen(storageReportProvider, (_, _) {});
  container.listen(storageSelectionProvider, (_, _) {});
}

List<Reclaimable> _items(ProviderContainer container) => storageReclaimables(
  container.read(storageReportProvider),
  syncBusy: container.read(storageSyncBusyProvider),
);

Future<StorageReport> _complete(ProviderContainer container) async {
  final complete = Completer<StorageReport>();
  final subscription = container.listen(storageReportProvider, (_, next) {
    if (!next.isLoading && next.hasError && !complete.isCompleted) {
      complete.completeError(next.error!, next.stackTrace);
    }
    if (!next.isLoading &&
        next.value?.complete == true &&
        !complete.isCompleted) {
      complete.complete(next.value!);
    }
  }, fireImmediately: true);
  try {
    return await complete.future.timeout(const Duration(seconds: 10));
  } finally {
    subscription.close();
  }
}

void main() {
  late Directory root;
  setUpAll(() {
    root = Directory.systemTemp.createTempSync('storage-controller-');
    PlatformService.get().applicationSupportPath = '${root.path}/support';
    PlatformService.get().applicationCachePath = '${root.path}/cache';
    FastImageRuntime.configure(
      imageDir: '${root.path}/support/image',
      thumbDir: '${root.path}/support/image/thumb',
    );
  });
  tearDownAll(() => root.deleteSync(recursive: true));
  tearDown(() async {
    await getIt.reset();
    for (final entity in root.listSync()) {
      entity.deleteSync(recursive: true);
    }
  });

  File write(String path, int bytes) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    return file..writeAsBytesSync(List.filled(bytes, 0));
  }

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
      final file = write('cache/keep', 123);
      final container = ProviderContainer.test(
        overrides: [
          storageReportProvider.overrideWith(
            (ref) => Stream.value(
              _report(
                candidates: {
                  .cache: [_cache],
                },
              ),
            ),
          ),
          syncControllerProvider.overrideWith(_SyncController.new),
        ],
      );
      _listen(container);
      await _complete(container);
      expect(_items(container).single.busy, isTrue);
      expect(
        container.read(storageSelectionProvider).selected(_items(container)),
        isEmpty,
      );
      expect(
        await container.read(storageSelectionProvider.notifier).clean(),
        0,
      );
      await _complete(container);
      expect(file.existsSync(), isTrue);
      runner.status.value = const SyncStatus();
      expect(_items(container).single.available, isTrue);
      final controller =
          container.read(syncControllerProvider.notifier) as _SyncController;
      controller.running(true);
      expect(_items(container).single.available, isFalse);
      controller.running(false);
      expect(_items(container).single.available, isTrue);
    },
  );

  test('sync starting after the snapshot makes clean skip cache', () async {
    final model = write('support/model/stale.part', 4);
    final cache = write('cache/in-use', 5);
    var busy = false;
    final container = ProviderContainer.test(
      overrides: [
        storageReportProvider.overrideWith(
          (ref) => Stream.value(
            _report(
              candidates: {
                .partialDownload: [
                  StorageCandidate(path: model.path, bytes: 4, area: .model),
                ],
                .cache: [
                  StorageCandidate(path: cache.path, bytes: 5, area: .cache),
                ],
              },
            ),
          ),
        ),
        storageSyncBusyProvider.overrideWith((ref) => busy),
      ],
    );
    _listen(container);
    await _complete(container);
    final clean = container.read(storageSelectionProvider.notifier).clean();
    busy = true;
    container.invalidate(storageSyncBusyProvider);
    expect(await clean, 4);
    expect(model.existsSync(), isFalse);
    expect(cache.existsSync(), isTrue);
    await _complete(container);
  });

  test(
    'invalidation clears loading after the replacement stream completes',
    () async {
      var calls = 0;
      var stream = Stream.value(
        _report(
          candidates: {
            .partialDownload: [_partial],
          },
        ),
      );
      final container = ProviderContainer.test(
        overrides: [
          storageReportProvider.overrideWith((ref) {
            calls++;
            return stream;
          }),
          storageSyncBusyProvider.overrideWith((ref) => false),
        ],
      );
      _listen(container);
      await _complete(container);
      container
          .read(storageSelectionProvider.notifier)
          .toggle(.partialDownload);
      final next = StreamController<StorageReport>();
      addTearDown(next.close);
      stream = next.stream;
      container.invalidate(storageReportProvider);
      expect(
        _items(container).every((i) => i.status.isLoading && !i.available),
        isTrue,
      );
      next.add(
        _report(
          candidates: {
            .partialDownload: [_partial],
          },
        ),
      );
      await _complete(container);
      expect(calls, 2);
      expect(_items(container).single.available, isTrue);
      expect(
        container.read(storageSelectionProvider).checked,
        isNot(contains(StorageCleanupKind.partialDownload)),
      );
    },
  );

  test('a cancelled scan cannot replace the replacement report', () async {
    final old = StreamController<StorageReport>();
    final next = StreamController<StorageReport>();
    addTearDown(old.close);
    addTearDown(next.close);
    var stream = old.stream;
    final container = ProviderContainer.test(
      overrides: [
        storageReportProvider.overrideWith((ref) => stream),
        storageSyncBusyProvider.overrideWith((ref) => false),
      ],
    );
    _listen(container);
    stream = next.stream;
    container.invalidate(storageReportProvider);
    container.read(storageReportProvider);
    next.add(
      _report(
        candidates: {
          .partialDownload: [_partial],
        },
      ),
    );
    await _complete(container);
    old.add(
      _report(
        candidates: {
          .cache: [_cache],
        },
      ),
    );
    await pumpEventQueue();
    expect(_items(container).single.kind, StorageCleanupKind.partialDownload);
  });

  test('safe clean uses the snapshot, returns actual bytes, and rows disappear on rescan', () async {
    final file = write('support/model/model.part', 40);
    var scans = 0;
    final container = ProviderContainer.test(
      overrides: [
        storageReportProvider.overrideWith((ref) {
          scans++;
          return Stream.value(
            _report(
              candidates: {
                if (file.existsSync())
                  .partialDownload: [
                    StorageCandidate(path: file.path, bytes: 50, area: .model),
                  ],
              },
            ),
          );
        }),
        storageSyncBusyProvider.overrideWith((ref) => false),
      ],
    );
    _listen(container);
    await _complete(container);
    expect(await container.read(storageSelectionProvider.notifier).clean(), 40);
    expect(file.existsSync(), isFalse);
    expect(container.read(storageSelectionProvider).cleaning, isFalse);
    await _complete(container);
    expect(scans, 2);
    expect(_items(container), isEmpty);
    // A regrown kind is immediately selectable; there is no retained cleaned id.
    file.writeAsBytesSync([1]);
    container.invalidate(storageReportProvider);
    await _complete(container);
    expect(
      container.read(storageSelectionProvider).selected(_items(container)),
      hasLength(1),
    );
  });

  test('unused media rechecks references and deletes only displayed files and derivatives', () async {
    final unused = write('support/file/unused.txt', 5);
    final newlyUsed = write('support/file/used.txt', 7);
    final image = write('support/image/used.jpg', 9);
    final derivative = write('support/image/thumb/used_512.jpg', 11);
    final orphan = write('support/image/orphan.jpg', 13);
    final orphanDerivative = write('support/image/thumb/orphan_512.jpg', 17);
    final video = write('support/video/video-used.mp4', 19);
    final thumb = write('support/video/thumbnail-used.jpeg', 23);
    final repository = _DiaryRepository();
    getIt.registerSingleton<DiaryRepository>(repository);
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    final container = ProviderContainer.test(
      overrides: [storageSyncBusyProvider.overrideWith((ref) => false)],
    );
    _listen(container);
    final scanned = await _complete(container);
    expect(scanned.candidates[StorageCleanupKind.unusedMedia]!.bytes, 104);
    repository.files.add('used.txt');
    repository.images.add('used.jpg');
    repository.videos.add('video-used.mp4');
    final unconfirmed = write('support/file/new.txt', 29);
    container.read(storageSelectionProvider.notifier).toggle(.unusedMedia);
    expect(await container.read(storageSelectionProvider.notifier).clean(), 35);
    for (final file in [unused, orphan, orphanDerivative]) {
      expect(file.existsSync(), isFalse);
    }
    for (final file in [
      newlyUsed,
      image,
      derivative,
      video,
      thumb,
      unconfirmed,
    ]) {
      expect(file.existsSync(), isTrue);
    }
    await _complete(container);
  });

  test('unfinished kinds and double clicks cannot start deletion', () async {
    final file = write('support/model/incomplete.part', 4);
    final container = ProviderContainer.test(
      overrides: [
        storageReportProvider.overrideWith(
          (ref) => Stream.value(
            StorageReport(
              bytes: const {},
              done: const {},
              area: .model,
              files: 0,
            ),
          ),
        ),
        storageSyncBusyProvider.overrideWith((ref) => false),
      ],
    );
    _listen(container);
    await pumpEventQueue();
    final notifier = container.read(storageSelectionProvider.notifier);
    final first = notifier.clean();
    expect(await notifier.clean(), 0);
    expect(await first, 0);
    expect(file.existsSync(), isTrue);
  });

  test('a failed report disables all rows until retry succeeds', () async {
    var fail = true;
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        storageReportProvider.overrideWith(
          (ref) => fail
              ? Stream.error(StateError('failed'))
              : Stream.value(
                  _report(
                    candidates: {
                      .partialDownload: [_partial],
                    },
                  ),
                ),
        ),
        storageSyncBusyProvider.overrideWith((ref) => false),
      ],
    );
    _listen(container);
    await pumpEventQueue();
    await container.pump();
    expect(_items(container), hasLength(StorageCleanupKind.values.length));
    expect(
      _items(container).every((i) => i.status.hasError && !i.available),
      isTrue,
    );
    fail = false;
    container.invalidate(storageReportProvider);
    await _complete(container);
    expect(_items(container).single.available, isTrue);
  });
}
