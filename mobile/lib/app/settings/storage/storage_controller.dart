import 'dart:async';
import 'dart:io';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_controller.g.dart';

@riverpod
Stream<StorageScanProgress> storageUsage(Ref ref) => StorageScanner().scan();

@riverpod
Future<List<StrayModelFile>> storageStrayModels(Ref ref) => strayModelFiles();

enum ReclaimSafety { safe, careful }

enum ReclaimKind { retiredMood, unusedModel, partial, cache, orphan, legacy }

class Reclaimable {
  final String id;
  final StorageArea area;
  final int bytes;
  final ReclaimSafety safety;
  final bool busy;
  final bool ready;
  final ReclaimKind kind;
  final Map<MediaType, int> counts;
  final Map<StorageArea, int> areaBytes;
  final Future<int> Function()? reclaim;

  const Reclaimable({
    required this.id,
    required this.area,
    required this.kind,
    this.bytes = 0,
    this.safety = .safe,
    this.busy = false,
    this.ready = false,
    this.counts = const {},
    this.areaBytes = const {},
    this.reclaim,
  });

  bool get available => ready && !busy && bytes > 0;
  int bytesIn(Iterable<StorageArea> areas) => areaBytes.isEmpty
      ? (areas.contains(area) ? bytes : 0)
      : areaBytes.entries
            .where((e) => areas.contains(e.key))
            .fold(0, (s, e) => s + e.value);
  Reclaimable withBusy(bool value) => Reclaimable(
    id: id,
    area: area,
    kind: kind,
    bytes: bytes,
    safety: safety,
    busy: value,
    ready: ready,
    counts: counts,
    areaBytes: areaBytes,
    reclaim: reclaim,
  );
}

class StorageState {
  final StorageScanProgress? progress;
  final List<Reclaimable> items;
  final Set<String> checked;
  final Set<String> cleaned;
  final bool cleaning;
  final Object? error;

  const StorageState({
    this.progress,
    this.items = const [],
    this.checked = const {},
    this.cleaned = const {},
    this.cleaning = false,
    this.error,
  });

  bool get scanning =>
      error == null &&
      (progress?.complete != true || items.any((i) => !i.ready));
  List<Reclaimable> get selected => items
      .where(
        (i) => i.available && checked.contains(i.id) && !cleaned.contains(i.id),
      )
      .toList();
  int get selectedBytes => selected.fold(0, (sum, i) => sum + i.bytes);
  int get reclaimableBytes => items
      .where((i) => i.ready && !cleaned.contains(i.id))
      .fold(0, (sum, i) => sum + i.bytes);
  bool get needsConfirmation => selected.any((i) => i.safety == .careful);

  StorageState copyWith({
    StorageScanProgress? progress,
    List<Reclaimable>? items,
    Set<String>? checked,
    Set<String>? cleaned,
    bool? cleaning,
    Object? error,
  }) => StorageState(
    progress: progress ?? this.progress,
    items: items ?? this.items,
    checked: checked ?? this.checked,
    cleaned: cleaned ?? this.cleaned,
    cleaning: cleaning ?? this.cleaning,
    error: error ?? this.error,
  );
}

@riverpod
class StorageController extends _$StorageController {
  final _started = <String>{};
  int _generation = 0;

  @override
  StorageState build() {
    const initial = StorageState(
      items: [
        Reclaimable(id: 'models', area: .model, kind: .unusedModel),
        Reclaimable(id: 'partial', area: .model, kind: .partial),
        Reclaimable(id: 'cache', area: .cache, kind: .cache),
        Reclaimable(
          id: 'orphan',
          area: .image,
          kind: .orphan,
          safety: .careful,
        ),
        Reclaimable(
          id: 'legacy',
          area: .legacyBackups,
          kind: .legacy,
          safety: .careful,
        ),
      ],
      checked: {'retiredMood', 'unusedModel', 'partial', 'cache'},
    );
    ref.listen(storageUsageProvider, (_, next) {
      next.whenData(_progress);
      if (next.hasError) state = state.copyWith(error: next.error);
    });
    ref.listen(syncControllerProvider, (_, _) => _busy(_syncing));
    final status = getIt<SyncRunner>().status;
    void busyChanged() => _busy(_syncing);
    status.addListener(busyChanged);
    ref.onDispose(() => status.removeListener(busyChanged));
    Future.microtask(() {
      if (!ref.mounted) return;
      ref.read(storageUsageProvider).whenData(_progress);
      _busy(_syncing);
    });
    return initial;
  }

  bool get _syncing =>
      ref.read(syncControllerProvider) is SyncRunning ||
      getIt<SyncRunner>().isRunning;

  void _busy(bool busy) => state = state.copyWith(
    items: [
      for (final item in state.items)
        item.kind == .cache ? item.withBusy(busy) : item,
    ],
  );

  void _progress(StorageScanProgress progress) {
    state = state.copyWith(progress: progress);
    if (progress.done.contains(StorageArea.model) && _started.add('models')) {
      unawaited(_models());
    }
    if (progress.done.contains(StorageArea.cache)) {
      _replace(
        {'cache'},
        [
          Reclaimable(
            id: 'cache',
            area: .cache,
            kind: .cache,
            ready: true,
            bytes: progress.reclaimableCacheBytes,
            busy: _syncing,
            reclaim: () => AppFiles.clearCache(),
          ),
        ],
      );
    }
    if (progress.done.containsAll({
          StorageArea.image,
          StorageArea.audio,
          StorageArea.video,
          StorageArea.file,
        }) &&
        _started.add('orphan')) {
      unawaited(_orphans());
    }
    if (progress.done.contains(StorageArea.legacyBackups) &&
        _started.add('legacy')) {
      unawaited(_legacy());
    }
  }

  void _replace(Set<String> ids, List<Reclaimable> items) {
    if (!ref.mounted) return;
    final at = state.items.indexWhere((i) => ids.contains(i.id));
    final updated = state.items.where((i) => !ids.contains(i.id)).toList();
    updated.insertAll(at < 0 ? updated.length : at, items);
    state = state.copyWith(items: updated);
  }

  Future<void> _models() async {
    final generation = _generation;
    try {
      final files = await ref.read(storageStrayModelsProvider.future);
      if (!ref.mounted || generation != _generation) return;
      _replace(
        {'models', 'retiredMood', 'unusedModel', 'partial'},
        [
          for (final kind in StrayModelKind.values)
            Reclaimable(
              id: switch (kind) {
                .retiredMood => 'retiredMood',
                .unused => 'unusedModel',
                .partial => 'partial',
              },
              area: .model,
              kind: switch (kind) {
                .retiredMood => .retiredMood,
                .unused => .unusedModel,
                .partial => .partial,
              },
              ready: true,
              bytes: files
                  .where((f) => f.kind == kind)
                  .fold(0, (s, f) => s + f.bytes),
              reclaim: () async {
                var freed = 0;
                for (final file in files.where((f) => f.kind == kind)) {
                  try {
                    final bytes = await File(file.path).length();
                    if (await AppFiles.deleteFile(file.path)) freed += bytes;
                  } on PathNotFoundException {
                    // A download or another cleaner already removed it.
                  }
                }
                return freed;
              },
            ),
        ],
      );
    } catch (e, stack) {
      logger.e('storage scan failed', error: e, stackTrace: stack);
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(error: e);
      }
    }
  }

  Future<MediaCleanupReport> _scanOrphans() async {
    final used = await getIt<DiaryRepository>().collectReferencedMedia();
    return AppFiles.scanOrphanMedia(
      usedImages: used.images,
      usedAudios: used.audios,
      usedVideos: used.videos,
      usedFiles: used.files,
    );
  }

  Future<void> _orphans() async {
    final generation = _generation;
    try {
      final report = await _scanOrphans();
      if (!ref.mounted || generation != _generation) return;
      final counts = <MediaType, int>{};
      final areaBytes = <StorageArea, int>{};
      for (final path in report.paths) {
        final segments = File(path).uri.pathSegments;
        final isThumb = segments.contains('thumb');
        final parent = File(path).parent.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last;
        final type = isThumb
            ? MediaType.image
            : MediaType.values.where((t) => t.value == parent).firstOrNull;
        if (type == null) continue;
        final area = switch (type) {
          .image => StorageArea.image,
          .audio => StorageArea.audio,
          .video => StorageArea.video,
          .file => StorageArea.file,
        };
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.length();
          areaBytes.update(area, (n) => n + bytes, ifAbsent: () => bytes);
        }
        if (!isThumb && !segments.last.startsWith('thumbnail-')) {
          counts.update(type, (n) => n + 1, ifAbsent: () => 1);
        }
      }
      if (!ref.mounted || generation != _generation) return;
      _replace(
        {'orphan'},
        [
          Reclaimable(
            id: 'orphan',
            area: .image,
            kind: .orphan,
            safety: .careful,
            ready: true,
            bytes: report.bytes,
            counts: counts,
            areaBytes: areaBytes,
            // Recheck references immediately before deletion: sync or an editor may
            // have started using a file since the displayed scan.
            reclaim: () async {
              final fresh = await _scanOrphans();
              final confirmed = report.paths.toSet();
              var freed = 0;
              final paths = <String>[];
              for (final path in fresh.paths.where(confirmed.contains)) {
                try {
                  freed += await File(path).length();
                  paths.add(path);
                } on PathNotFoundException {
                  // Already removed.
                }
              }
              await AppFiles.deleteOrphanMedia(
                MediaCleanupReport(paths: paths, bytes: freed),
              );
              return freed;
            },
          ),
        ],
      );
    } catch (e, stack) {
      logger.e('storage scan failed', error: e, stackTrace: stack);
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(error: e);
      }
    }
  }

  Future<void> _legacy() async {
    final generation = _generation;
    try {
      final backups = LegacyBackups();
      final files = await backups.scan();
      var bytes = 0;
      for (final file in files) {
        if (await file.exists()) bytes += await file.length();
      }
      if (!ref.mounted || generation != _generation) return;
      _replace(
        {'legacy'},
        [
          Reclaimable(
            id: 'legacy',
            area: .legacyBackups,
            kind: .legacy,
            safety: .careful,
            ready: true,
            bytes: bytes,
            reclaim: backups.delete,
          ),
        ],
      );
    } catch (e, stack) {
      logger.e('storage scan failed', error: e, stackTrace: stack);
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(error: e);
      }
    }
  }

  void toggle(String id) {
    final checked = {...state.checked};
    if (!checked.add(id)) checked.remove(id);
    state = state.copyWith(checked: checked);
  }

  Future<int> clean() async {
    if (state.cleaning) return 0;
    final selected = state.selected
        .where((i) => i.kind != .cache || !_syncing)
        .toList();
    state = state.copyWith(cleaning: true);
    var freed = 0;
    try {
      for (final item in selected) {
        if (item.kind == .cache && _syncing) continue;
        freed += await item.reclaim?.call() ?? 0;
        if (!ref.mounted) continue;
        state = state.copyWith(
          cleaned: {...state.cleaned, item.id},
          checked: {...state.checked}..remove(item.id),
        );
      }
      return freed;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(cleaning: false);
        _generation++;
        _started.clear();
        ref.invalidate(storageStrayModelsProvider);
        ref.invalidate(storageUsageProvider);
      }
    }
  }
}
