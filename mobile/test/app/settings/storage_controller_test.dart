import 'dart:async';
import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_export/moodiary_export.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_mobile/app/settings/storage/storage_controller.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';

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
  final batches = <List<Diary>>[];
  Future<void> Function()? beforeCollect;

  @override
  Future<void> insertDiaries(
    List<Diary> incoming, {
    bool fromSync = false,
    IndexMode index = .inline,
  }) async {
    batches.add(List.of(incoming));
    for (final diary in incoming) {
      images.addAll(diary.imageName);
    }
  }

  @override
  Future<ReferencedMedia> collectReferencedMedia() async {
    await beforeCollect?.call();
    return (
      images: Set.of(images),
      audios: <String>{},
      videos: Set.of(videos),
      files: Set.of(files),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Categories implements CategoryRepository {
  @override
  Future<List<Category>> getAllCategories() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Places implements PlaceRepository {
  @override
  Future<List<Place>> getAllPlaces() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HeifDecoder implements IHeifDecoder {
  @override
  Future<String?> convert(String srcPath, {required String outputPath}) async {
    expect(
      MediaHolds.contains(.image, File(outputPath).uri.pathSegments.last),
      isTrue,
    );
    await File(srcPath).copy(outputPath);
    return outputPath;
  }
}

class _ImportMedia implements ImportMediaStore {
  final stagedLast = Completer<void>();
  final release = Completer<void>();
  var count = 0;

  @override
  Future<String?> save(String path, ImportMediaKind kind) async {
    final name = 'image-${++count}.jpg';
    await File(path).copy(AppFiles.getRealPath('image', name));
    if (count == 101) {
      stagedLast.complete();
      await release.future;
    }
    return name;
  }
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
  container.listen(storageDisplayControllerProvider, (_, _) {});
  container.listen(storageSelectionProvider, (_, _) {});
}

List<Reclaimable> _items(ProviderContainer container) => storageReclaimables(
  container.read(storageDisplayControllerProvider).report,
  syncBusy: container.read(storageSyncBusyProvider),
  canClean: container.read(storageDisplayControllerProvider).canClean,
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
  TestWidgetsFlutterBinding.ensureInitialized();
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
  setUp(() => getIt.registerSingleton<SyncCancellation>(SyncCancellation()));
  tearDown(() async {
    await getIt.reset();
    for (final entity in root.listSync()) {
      entity.deleteSync(recursive: true);
    }
  });

  File write(String path, int bytes) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List.filled(bytes, 0));
    file.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
    return file;
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
        await container
            .read(storageSelectionProvider.notifier)
            .clean(_items(container)),
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
    final media = write('support/file/incoming.txt', 6);
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
                .unusedMedia: [
                  StorageCandidate(path: media.path, bytes: 6, area: .file),
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
    final clean = container
        .read(storageSelectionProvider.notifier)
        .clean(_items(container));
    busy = true;
    container.invalidate(storageSyncBusyProvider);
    expect(await clean, 4);
    expect(model.existsSync(), isFalse);
    expect(cache.existsSync(), isTrue);
    expect(media.existsSync(), isTrue);
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
      expect(_items(container).every((i) => !i.available), isTrue);
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
    expect(
      await container
          .read(storageSelectionProvider.notifier)
          .clean(_items(container)),
      40,
    );
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
    expect(
      await container
          .read(storageSelectionProvider.notifier)
          .clean(_items(container)),
      35,
    );
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

  for (final kind in ['image', 'heic', 'video', 'file']) {
    test(
      '$kind saved this process survives a stale unused-media snapshot',
      () async {
        await AppFiles.initCreateDir();
        getIt.registerSingleton<DiaryRepository>(_DiaryRepository());
        getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
        getIt.registerSingleton<IHeifDecoder>(_HeifDecoder());
        const channel = MethodChannel('fc_native_video_thumbnail');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              final args = call.arguments as Map;
              final path = args['destFile'] as String;
              expect(
                MediaHolds.contains(.video, File(path).uri.pathSegments.last),
                isTrue,
              );
              await File(path).writeAsBytes([1, 2, 3]);
              return true;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });
        final source = write('source.${kind == 'image' ? 'png' : kind}', 7);
        final xfile = XFile(source.path);
        final MediaType type;
        final String name;
        if (kind == 'video') {
          type = .video;
          name = (await MediaManager.saveVideo(
            videoFileList: [xfile],
          ))[source.path]!;
        } else if (kind == 'file') {
          type = .file;
          name = (await MediaManager.saveAttachment(xfile))!.name;
        } else {
          type = .image;
          name = (await MediaManager.saveImage(xfile))!;
        }
        if (kind == 'heic') expect(name, endsWith('.jpg'));
        final protected = [File(AppFiles.getRealPath(type.value, name))];
        if (type == .image) {
          for (final derivative in FastImageDerivatives.derivativeNamesOf(
            name,
          )) {
            protected.add(write('support/image/thumb/$derivative', 3));
          }
        } else if (type == .video) {
          protected.add(File(AppFiles.getRealPath('thumbnail', name)));
        }
        final orphan = write('support/file/orphan.txt', 5);
        // Simulate an already displayed snapshot which did not know the holds.
        final stale = await StorageScanner().scan(StorageScanInput()).last;
        expect(
          stale.candidates[StorageCleanupKind.unusedMedia]!.files.map(
            (f) => f.path,
          ),
          containsAll(protected.map((f) => f.path)),
        );
        final live = ProviderContainer.test();
        final scanned = await _complete(live);
        expect(
          scanned.candidates[StorageCleanupKind.unusedMedia]!.files.map(
            (f) => f.path,
          ),
          [orphan.path],
        );
        final container = ProviderContainer.test(
          overrides: [
            storageReportProvider.overrideWith((ref) => Stream.value(stale)),
            storageSyncBusyProvider.overrideWith((ref) => false),
          ],
        );
        _listen(container);
        await _complete(container);
        expect(
          await container
              .read(storageSelectionProvider.notifier)
              .clean(_items(container)),
          5,
        );
        expect(orphan.existsSync(), isFalse);
        for (final file in protected) {
          expect(file.existsSync(), isTrue, reason: file.path);
        }
        await _complete(container);
      },
    );
  }

  test(
    'cleanup keeps live derivatives shared by an orphan image stem',
    () async {
      final orphan = write('support/image/foo.heic', 3);
      final live = write('support/image/foo.jpg', 5);
      final derivatives = [
        for (final name in FastImageDerivatives.derivativeNamesOf('foo.jpg'))
          write('support/image/thumb/$name', 7),
      ];
      final repository = _DiaryRepository()..images.add('foo.jpg');
      getIt.registerSingleton<DiaryRepository>(repository);
      getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
      final container = ProviderContainer.test(
        overrides: [storageSyncBusyProvider.overrideWith((ref) => false)],
      );
      _listen(container);
      final scan = await _complete(container);
      expect(
        scan.candidates[StorageCleanupKind.unusedMedia]!.files.map(
          (f) => f.path,
        ),
        [orphan.path],
      );
      expect(
        await container
            .read(storageSelectionProvider.notifier)
            .clean(_items(container)),
        3,
      );
      expect(orphan.existsSync(), isFalse);
      for (final file in [live, ...derivatives]) {
        expect(file.existsSync(), isTrue);
      }
      await _complete(container);
    },
  );

  test(
    'a stop requested behind cleanup reaches queued sync; sync resets it',
    () async {
      final orphan = write('support/file/orphan.txt', 5);
      final entered = Completer<void>();
      final release = Completer<void>();
      final cancellation = getIt<SyncCancellation>();
      final repository = _DiaryRepository();
      repository.beforeCollect = () async {
        entered.complete();
        await release.future;
        expect(cancellation.isRequested, isTrue);
        repository.beforeCollect = null;
      };
      getIt.registerSingleton<DiaryRepository>(repository);
      final container = ProviderContainer.test(
        overrides: [
          storageSyncBusyProvider.overrideWith((ref) => false),
          storageReportProvider.overrideWith(
            (ref) => Stream.value(
              _report(
                candidates: {
                  .unusedMedia: [
                    StorageCandidate(
                      path: orphan.path,
                      bytes: 5,
                      area: .file,
                      mediaName: 'orphan.txt',
                    ),
                  ],
                },
              ),
            ),
          ),
        ],
      );
      _listen(container);
      await _complete(container);
      final clean = container
          .read(storageSelectionProvider.notifier)
          .clean(_items(container));
      await entered.future;
      var started = false;
      final sync = runSyncExclusive(() async {
        started = true;
        return cancellation.isRequested;
      });
      cancellation.requestStop();
      await pumpEventQueue();
      expect(started, isFalse);
      release.complete();
      expect(await clean, 5);
      expect(await sync, isTrue);
      expect(cancellation.isRequested, isFalse);
      await _complete(container);
    },
  );

  test(
    'cleanup waits for all Markdown import batches before revalidating media',
    () async {
      await AppFiles.initCreateDir();
      final source = Directory('${root.path}/source')..createSync();
      File('${source.path}/photo.jpg').writeAsBytesSync([1, 2, 3]);
      for (var i = 0; i < 101; i++) {
        // Unique source paths prevent the import stage's deduplication.
        File('${source.path}/photo-$i.jpg').writeAsBytesSync([1, 2, 3]);
        File('${source.path}/$i.md')
            .writeAsStringSync('![photo](photo-$i.jpg)');
      }
      final repository = _DiaryRepository();
      getIt.registerSingleton<DiaryRepository>(repository);
      getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
      final media = _ImportMedia();
      final importing = MarkdownImporter(
        diaries: repository,
        categories: _Categories(),
        places: _Places(),
        media: media,
      ).run(MarkdownImportSource.scan(source));
      await media.stagedLast.future;
      expect(repository.batches.map((batch) => batch.length), [100]);
      final container = ProviderContainer.test(
        overrides: [storageSyncBusyProvider.overrideWith((ref) => false)],
      );
      _listen(container);
      final scan = await _complete(container);
      expect(
        scan.candidates[StorageCleanupKind.unusedMedia]!.files.single.mediaName,
        'image-101.jpg',
      );
      var cleaned = false;
      final clean = container
          .read(storageSelectionProvider.notifier)
          .clean(_items(container))
          .then((bytes) {
            cleaned = true;
            return bytes;
          });
      await pumpEventQueue();
      expect(cleaned, isFalse);
      media.release.complete();
      expect((await importing).diaries, 101);
      expect(repository.batches.map((batch) => batch.length), [100, 1]);
      expect(await clean, 0);
      for (var i = 1; i <= 101; i++) {
        expect(
          File(AppFiles.getRealPath('image', 'image-$i.jpg')).existsSync(),
          isTrue,
        );
      }
      await _complete(container);
    },
  );

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
    final first = notifier.clean(_items(container));
    expect(await notifier.clean(_items(container)), 0);
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
    expect(container.read(storageDisplayControllerProvider).error, isNotNull);
    expect(_items(container), isEmpty);
    fail = false;
    container.invalidate(storageReportProvider);
    await _complete(container);
    expect(_items(container).single.available, isTrue);
  });

  test(
    'a rescan keeps the finished report on screen until it completes',
    () async {
      final second = StreamController<StorageReport>();
      addTearDown(second.close);
      var round = 0;
      final container = ProviderContainer.test(
        overrides: [
          storageReportProvider.overrideWith(
            (ref) => round++ == 0
                ? Stream.value(
                    _report(
                      candidates: {
                        .cache: [_cache],
                      },
                    ),
                  )
                : second.stream,
          ),
          storageSyncBusyProvider.overrideWith((ref) => false),
        ],
      );
      _listen(container);
      await _complete(container);
      expect(_items(container).single.kind, StorageCleanupKind.cache);

      container.invalidate(storageReportProvider);
      await pumpEventQueue();
      second.add(
        StorageReport(bytes: const {}, done: const {}, area: .model, files: 0),
      );
      await pumpEventQueue();
      final display = container.read(storageDisplayControllerProvider);
      expect(display.scanning, isTrue);
      expect(display.report!.complete, isTrue);
      expect(_items(container).single.kind, StorageCleanupKind.cache);

      second.add(_report());
      await pumpEventQueue();
      expect(
        container.read(storageDisplayControllerProvider).scanning,
        isFalse,
      );
      expect(_items(container), isEmpty);
    },
  );

  test('sync busy disables and skips unused media too', () async {
    final file = write('support/file/incoming.txt', 5);
    final container = ProviderContainer.test(
      overrides: [
        storageSyncBusyProvider.overrideWith((ref) => true),
        storageReportProvider.overrideWith(
          (ref) => Stream.value(
            _report(
              candidates: {
                .unusedMedia: [
                  StorageCandidate(
                    path: file.path,
                    bytes: 5,
                    area: .file,
                    mediaName: 'incoming.txt',
                  ),
                ],
              },
            ),
          ),
        ),
      ],
    );
    _listen(container);
    await _complete(container);
    expect(_items(container).single.busy, isTrue);
    expect(_items(container).single.available, isFalse);
    expect(
      await container
          .read(storageSelectionProvider.notifier)
          .clean(_items(container)),
      0,
    );
    expect(file.existsSync(), isTrue);
    await _complete(container);
  });

  for (final kind in [
    StorageCleanupKind.cache,
    StorageCleanupKind.unusedMedia,
  ]) {
    test(
      '$kind cleanup waits for the shared lock and rechecks references inside it',
      () async {
        final file = write(
          kind == .cache ? 'cache/snapshot' : 'support/file/incoming.txt',
          5,
        );
        final repository = _DiaryRepository();
        getIt.registerSingleton<DiaryRepository>(repository);
        final container = ProviderContainer.test(
          overrides: [
            storageSyncBusyProvider.overrideWith((ref) => false),
            storageReportProvider.overrideWith(
              (ref) => Stream.value(
                _report(
                  candidates: {
                    kind: [
                      StorageCandidate(
                        path: file.path,
                        bytes: 5,
                        area: kind == .cache ? .cache : .file,
                        mediaName: 'incoming.txt',
                      ),
                    ],
                  },
                ),
              ),
            ),
          ],
        );
        _listen(container);
        await _complete(container);
        final entered = Completer<void>();
        final release = Completer<void>();
        final owner = runSyncExclusive(() async {
          entered.complete();
          await release.future;
          // Incoming media is referenced only at the end of the operation.
          repository.files.add('incoming.txt');
        });
        await entered.future;
        var finished = false;
        final clean = container
            .read(storageSelectionProvider.notifier)
            .clean(_items(container))
            .then((bytes) {
              finished = true;
              return bytes;
            });
        await pumpEventQueue();
        expect(finished, isFalse);
        expect(file.existsSync(), isTrue);
        release.complete();
        await owner;
        expect(await clean, kind == .cache ? 5 : 0);
        expect(file.existsSync(), kind != .cache);
        await _complete(container);
      },
    );
  }

  test(
    'clean deletes only the confirmed snapshot regardless of later selection',
    () async {
      final confirmedFile = write('support/model/confirmed.bin', 5);
      final otherFile = write('support/model/other.bin', 7);
      final laterFile = write('support/model/later.bin', 11);
      var includeLater = false;
      final container = ProviderContainer.test(
        overrides: [
          storageSyncBusyProvider.overrideWith((ref) => false),
          storageReportProvider.overrideWith(
            (ref) => Stream.value(
              _report(
                candidates: {
                  .unusedModel: [
                    StorageCandidate(
                      path: confirmedFile.path,
                      bytes: 5,
                      area: .model,
                    ),
                    if (includeLater)
                      StorageCandidate(
                        path: laterFile.path,
                        bytes: 11,
                        area: .model,
                      ),
                  ],
                  .retiredModel: [
                    StorageCandidate(
                      path: otherFile.path,
                      bytes: 7,
                      area: .model,
                    ),
                  ],
                },
              ),
            ),
          ),
        ],
      );
      _listen(container);
      await _complete(container);
      final confirmed = List<Reclaimable>.unmodifiable(
        _items(container).where((item) => item.kind == .unusedModel),
      );
      includeLater = true;
      container.invalidate(storageReportProvider);
      await _complete(container);
      container.read(storageSelectionProvider.notifier).toggle(.unusedModel);
      expect(
        await container
            .read(storageSelectionProvider.notifier)
            .clean(confirmed),
        5,
      );
      expect(confirmedFile.existsSync(), isFalse);
      expect(otherFile.existsSync(), isTrue);
      expect(laterFile.existsSync(), isTrue);
      await _complete(container);
    },
  );

  test(
    'partials touched after scanning are skipped even if still old',
    () async {
      final touched = write('support/model/touched.part', 5);
      final fresh = write('support/model/fresh.part', 7);
      final old = write('support/model/old.part', 11);
      final snapshot = [
        for (final file in [touched, fresh, old])
          StorageCandidate(
            path: file.path,
            bytes: file.lengthSync(),
            area: .model,
            modified: file.lastModifiedSync(),
          ),
      ];
      final container = ProviderContainer.test(
        overrides: [
          storageSyncBusyProvider.overrideWith((ref) => false),
          storageReportProvider.overrideWith(
            (ref) =>
                Stream.value(_report(candidates: {.partialDownload: snapshot})),
          ),
        ],
      );
      _listen(container);
      await _complete(container);
      touched.setLastModifiedSync(
        DateTime.now().subtract(const Duration(minutes: 90)),
      );
      fresh.setLastModifiedSync(DateTime.now());
      expect(
        await container
            .read(storageSelectionProvider.notifier)
            .clean(_items(container)),
        11,
      );
      expect(touched.existsSync(), isTrue);
      expect(fresh.existsSync(), isTrue);
      expect(old.existsSync(), isFalse);
      await _complete(container);
    },
  );

  test('a partial claimed after scanning is skipped', () async {
    // A stalled download can leave its .part untouched past the grace period.
    final held = write('support/model/held.part', 13);
    addTearDown(
      () => EmbeddingModelManager.debugHoldPartialDownload(
        held.path,
        held: false,
      ),
    );
    final container = ProviderContainer.test(
      overrides: [
        storageSyncBusyProvider.overrideWith((ref) => false),
        storageReportProvider.overrideWith(
          (ref) => Stream.value(
            _report(
              candidates: {
                .partialDownload: [
                  StorageCandidate(
                    path: held.path,
                    bytes: 13,
                    area: .model,
                    modified: held.lastModifiedSync(),
                  ),
                ],
              },
            ),
          ),
        ),
      ],
    );
    _listen(container);
    await _complete(container);
    EmbeddingModelManager.debugHoldPartialDownload(held.path);
    expect(
      await container
          .read(storageSelectionProvider.notifier)
          .clean(_items(container)),
      0,
    );
    expect(held.existsSync(), isTrue);
    await _complete(container);
  });

  test('partial deletion finishes before a later download can claim its path', () async {
    final file = write('support/model/claim-after-delete.part', 13);
    final container = ProviderContainer.test(
      overrides: [
        storageReportProvider.overrideWith(
          (ref) => Stream.value(
            _report(
              candidates: {
                .partialDownload: [
                  StorageCandidate(
                    path: file.path,
                    bytes: 13,
                    area: .model,
                    modified: file.lastModifiedSync(),
                  ),
                ],
              },
            ),
          ),
        ),
        storageSyncBusyProvider.overrideWith((ref) => false),
      ],
    );
    _listen(container);
    await _complete(container);
    final clean = container
        .read(storageSelectionProvider.notifier)
        .clean(_items(container));
    // No await: the old file must already be deleted before a new claim/write.
    expect(file.existsSync(), isFalse);
    EmbeddingModelManager.debugHoldPartialDownload(file.path);
    addTearDown(
      () => EmbeddingModelManager.debugHoldPartialDownload(
        file.path,
        held: false,
      ),
    );
    file.writeAsBytesSync([1, 2, 3]);
    expect(await clean, 13);
    expect(file.readAsBytesSync(), [1, 2, 3]);
    await _complete(container);
  });

  for (final fail in [false, true]) {
    test(
      'previous report cannot be cleaned during ${fail ? 'error' : 'rescan'}',
      () async {
        final file = write('support/model/keep.bin', 5);
        final next = StreamController<StorageReport>();
        addTearDown(next.close);
        var round = 0;
        final container = ProviderContainer.test(
          retry: (_, _) => null,
          overrides: [
            storageSyncBusyProvider.overrideWith((ref) => false),
            storageReportProvider.overrideWith(
              (ref) => round++ == 0
                  ? Stream.value(
                      _report(
                        candidates: {
                          .unusedModel: [
                            StorageCandidate(
                              path: file.path,
                              bytes: 5,
                              area: .model,
                            ),
                          ],
                        },
                      ),
                    )
                  : next.stream,
            ),
          ],
        );
        _listen(container);
        await _complete(container);
        final confirmed = _items(container);
        container.invalidate(storageReportProvider);
        await pumpEventQueue();
        if (fail) {
          next.addError(StateError('failed'));
          await pumpEventQueue();
        }
        final display = container.read(storageDisplayControllerProvider);
        expect(display.report!.complete, isTrue);
        expect(display.canClean, isFalse);
        expect(_items(container).single.available, isFalse);
        expect(
          await container
              .read(storageSelectionProvider.notifier)
              .clean(confirmed),
          0,
        );
        expect(file.existsSync(), isTrue);
      },
    );
  }

  test('cleaned kinds leave the screen before the rescan finishes', () async {
    final container = ProviderContainer.test(
      overrides: [
        storageReportProvider.overrideWith(
          (ref) => Stream.value(
            _report(
              candidates: {
                .cache: [_cache],
                .partialDownload: [_partial],
              },
            ),
          ),
        ),
        storageSyncBusyProvider.overrideWith((ref) => false),
      ],
    );
    _listen(container);
    await _complete(container);
    container.read(storageDisplayControllerProvider.notifier).dropCleaned({
      StorageCleanupKind.cache,
    });
    expect(_items(container).single.kind, StorageCleanupKind.partialDownload);
  });
}
