import 'dart:io';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_controller.g.dart';

@riverpod
Stream<StorageScanProgress> storageUsage(Ref ref) => StorageScanner().scan();

@riverpod
Future<List<StrayModelFile>> storageStrayModels(Ref ref) => strayModelFiles();

class StorageOrphanMedia {
  final MediaCleanupReport report;
  final Map<MediaType, int> counts;
  final Map<StorageArea, int> areaBytes;

  StorageOrphanMedia({
    required MediaCleanupReport report,
    Map<MediaType, int> counts = const {},
    Map<StorageArea, int> areaBytes = const {},
  }) : report = MediaCleanupReport(
         paths: List.unmodifiable(report.paths),
         bytes: report.bytes,
       ),
       counts = Map.unmodifiable(counts),
       areaBytes = Map.unmodifiable(areaBytes);
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

@riverpod
Future<StorageOrphanMedia> storageOrphanMedia(Ref ref) async {
  final report = await _scanOrphans();
  final counts = <MediaType, int>{};
  final areaBytes = <StorageArea, int>{};
  for (final path in report.paths) {
    final file = File(path);
    final segments = file.uri.pathSegments;
    final isThumb = segments.contains('thumb');
    final parent = file.parent.uri.pathSegments.where((s) => s.isNotEmpty).last;
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
    if (await file.exists()) {
      final bytes = await file.length();
      areaBytes.update(area, (n) => n + bytes, ifAbsent: () => bytes);
    }
    if (!isThumb && !segments.last.startsWith('thumbnail-')) {
      counts.update(type, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return StorageOrphanMedia(
    report: report,
    counts: counts,
    areaBytes: areaBytes,
  );
}

class StorageLegacyBackups {
  final List<File> files;
  final int bytes;

  StorageLegacyBackups({required List<File> files, required this.bytes})
    : files = List.unmodifiable(files);
}

@riverpod
Future<StorageLegacyBackups> storageLegacyBackups(Ref ref) async {
  final files = await LegacyBackups().scan();
  var bytes = 0;
  for (final file in files) {
    if (await file.exists()) bytes += await file.length();
  }
  return StorageLegacyBackups(files: files, bytes: bytes);
}

@riverpod
AsyncValue<int> storageCacheReclaim(Ref ref) => ref
    .watch(storageUsageProvider)
    .when(
      skipLoadingOnRefresh: false,
      data: (progress) => progress.done.contains(StorageArea.cache)
          ? AsyncData(progress.reclaimableCacheBytes)
          : const AsyncLoading(),
      error: (error, stack) => AsyncError(error, stack),
      loading: () => const AsyncLoading(),
    );

@riverpod
bool storageSyncBusy(Ref ref) {
  final runner = getIt<SyncRunner>();
  void changed() => ref.invalidateSelf();
  runner.status.addListener(changed);
  ref.onDispose(() => runner.status.removeListener(changed));
  return ref.watch(syncControllerProvider) is SyncRunning || runner.isRunning;
}

enum ReclaimSafety { safe, careful }

enum ReclaimKind { retiredMood, unusedModel, partial, cache, orphan, legacy }

class Reclaimable {
  final String id;
  final StorageArea area;
  final AsyncValue<int> status;
  final ReclaimSafety safety;
  final bool busy;
  final ReclaimKind kind;
  final Map<MediaType, int> counts;
  final Map<StorageArea, int> areaBytes;

  const Reclaimable({
    required this.id,
    required this.area,
    required this.kind,
    required this.status,
    this.safety = .safe,
    this.busy = false,
    this.counts = const {},
    this.areaBytes = const {},
  });

  int get bytes => status.value ?? 0;
  bool get available =>
      !status.isLoading && !status.hasError && !busy && bytes > 0;
  int bytesIn(Iterable<StorageArea> areas) => areaBytes.isEmpty
      ? (areas.contains(area) ? bytes : 0)
      : areaBytes.entries
            .where((e) => areas.contains(e.key))
            .fold(0, (s, e) => s + e.value);
}

@riverpod
List<Reclaimable> storageReclaimables(Ref ref) {
  final models = ref.watch(storageStrayModelsProvider);
  final orphans = ref.watch(storageOrphanMediaProvider);
  final legacy = ref.watch(storageLegacyBackupsProvider);
  final cache = ref.watch(storageCacheReclaimProvider);
  final busy = ref.watch(storageSyncBusyProvider);
  return [
        for (final kind in StrayModelKind.values)
          Reclaimable(
            id: kind == .unused ? 'unusedModel' : kind.name,
            area: .model,
            kind: switch (kind) {
              .retiredMood => .retiredMood,
              .unused => .unusedModel,
              .partial => .partial,
            },
            status: models.whenData(
              (files) => files
                  .where((f) => f.kind == kind)
                  .fold(0, (sum, file) => sum + file.bytes),
            ),
          ),
        Reclaimable(
          id: 'cache',
          area: .cache,
          kind: .cache,
          status: cache,
          busy: busy,
        ),
        Reclaimable(
          id: 'orphan',
          area: .image,
          kind: .orphan,
          safety: .careful,
          status: orphans.whenData((value) => value.report.bytes),
          counts: orphans.value?.counts ?? const {},
          areaBytes: orphans.value?.areaBytes ?? const {},
        ),
        Reclaimable(
          id: 'legacy',
          area: .legacyBackups,
          kind: .legacy,
          safety: .careful,
          status: legacy.whenData((value) => value.bytes),
        ),
      ]
      .where((i) => i.status.isLoading || i.status.hasError || i.bytes > 0)
      .toList();
}

/// Accepts either Ref.invalidate or WidgetRef.invalidate.
void refreshStorage(void Function(ProviderOrFamily) invalidate) {
  invalidate(storageUsageProvider);
  invalidate(storageStrayModelsProvider);
  invalidate(storageOrphanMediaProvider);
  invalidate(storageLegacyBackupsProvider);
}

class StorageSelectionState {
  final Set<String> checked;
  final Set<String> cleaned;
  final bool cleaning;

  const StorageSelectionState({
    this.checked = const {'retiredMood', 'unusedModel', 'partial', 'cache'},
    this.cleaned = const {},
    this.cleaning = false,
  });

  List<Reclaimable> selected(List<Reclaimable> items) => items
      .where(
        (i) => i.available && checked.contains(i.id) && !cleaned.contains(i.id),
      )
      .toList();

  StorageSelectionState copyWith({
    Set<String>? checked,
    Set<String>? cleaned,
    bool? cleaning,
  }) => StorageSelectionState(
    checked: checked ?? this.checked,
    cleaned: cleaned ?? this.cleaned,
    cleaning: cleaning ?? this.cleaning,
  );
}

@riverpod
class StorageSelection extends _$StorageSelection {
  @override
  StorageSelectionState build() => const StorageSelectionState();

  void toggle(String id) {
    final checked = {...state.checked};
    if (!checked.add(id)) checked.remove(id);
    state = state.copyWith(checked: checked);
  }

  Future<int> clean() async {
    if (state.cleaning) return 0;
    final selected = state.selected(ref.read(storageReclaimablesProvider));
    // Snapshot the displayed candidates before any await or source refresh.
    final models = ref.read(storageStrayModelsProvider).value ?? const [];
    final orphans = ref.read(storageOrphanMediaProvider).value;
    state = state.copyWith(cleaning: true);
    var freed = 0;
    try {
      for (final item in selected) {
        if (item.kind == .cache && ref.read(storageSyncBusyProvider)) continue;
        freed += switch (item.kind) {
          .retiredMood || .unusedModel || .partial => await _deleteModels(
            models.where(
              (file) =>
                  switch (file.kind) {
                    .retiredMood => ReclaimKind.retiredMood,
                    .unused => ReclaimKind.unusedModel,
                    .partial => ReclaimKind.partial,
                  } ==
                  item.kind,
            ),
          ),
          .cache => await AppFiles.clearCache(),
          .orphan => await _deleteOrphans(orphans!.report),
          .legacy => await LegacyBackups().delete(),
        };
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
        refreshStorage(ref.invalidate);
      }
    }
  }
}

Future<int> _deleteModels(Iterable<StrayModelFile> files) async {
  var freed = 0;
  for (final file in files) {
    try {
      final bytes = await File(file.path).length();
      if (await AppFiles.deleteFile(file.path)) freed += bytes;
    } on PathNotFoundException {
      // A download or another cleaner already removed it.
    }
  }
  return freed;
}

Future<int> _deleteOrphans(MediaCleanupReport report) async {
  // Sync or an editor may have started using a file since the displayed scan.
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
}
