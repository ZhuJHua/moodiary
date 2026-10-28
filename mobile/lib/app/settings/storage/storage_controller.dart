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
Stream<StorageReport> storageReport(Ref ref) async* {
  final used = await getIt<DiaryRepository>().collectReferencedMedia();
  if (!ref.mounted) return;
  yield* StorageScanner().scan(
    StorageScanInput(
      referencedMedia: used,
      liveModelFiles: liveModelFileNames(),
      retiredModelStems: retiredModelStems,
      includeLegacyBackups: LegacyBackups().dbEngineMigrated,
    ),
  );
}

class StorageDisplay {
  /// What the page draws: the latest finished report, or the partial one on
  /// first open, before any scan has finished.
  final StorageReport? report;
  final bool scanning;
  final Object? error;

  bool get canClean => !scanning && error == null;

  const StorageDisplay({this.report, this.scanning = true, this.error});
}

/// Rescans (after a clean, or coming back from a linked page) keep the last
/// finished report on screen and swap it only when the new scan is done, so
/// rows and sizes don't drop to zero and grow back.
@riverpod
class StorageDisplayController extends _$StorageDisplayController {
  @override
  StorageDisplay build() {
    final live = ref.watch(storageReportProvider);
    final shown = stateOrNull?.report;
    if (live.hasError) {
      return StorageDisplay(report: shown, scanning: false, error: live.error);
    }
    final fresh = live.isLoading ? null : live.value;
    if (fresh != null && fresh.complete) {
      return StorageDisplay(report: fresh, scanning: false);
    }
    return StorageDisplay(
      report: shown?.complete == true ? shown : fresh,
      scanning: true,
    );
  }

  /// Cleaned kinds leave the screen at once instead of waiting for the rescan.
  void dropCleaned(Set<StorageCleanupKind> kinds) {
    final report = state.report;
    if (report == null || kinds.isEmpty) return;
    state = StorageDisplay(
      report: report.without(kinds),
      scanning: state.scanning,
      error: state.error,
    );
  }
}

@riverpod
bool storageSyncBusy(Ref ref) {
  final runner = getIt<SyncRunner>();
  void changed() => ref.invalidateSelf();
  runner.status.addListener(changed);
  ref.onDispose(() => runner.status.removeListener(changed));
  return ref.watch(syncControllerProvider) is SyncRunning || runner.isRunning;
}

enum ReclaimSafety { safe, careful }

class Reclaimable {
  final StorageCleanupKind kind;
  final AsyncValue<int> status;
  final bool busy;
  final bool enabled;
  final StorageCandidates? candidates;

  const Reclaimable({
    required this.kind,
    required this.status,
    this.busy = false,
    this.enabled = true,
    this.candidates,
  });

  ReclaimSafety get safety => switch (kind) {
    .unusedMedia || .legacyBackup => .careful,
    _ => .safe,
  };
  Map<MediaType, int> get counts => candidates?.counts ?? const {};
  int get bytes => status.value ?? 0;
  bool get available =>
      enabled && !status.isLoading && !status.hasError && !busy && bytes > 0;
  int bytesIn(Iterable<StorageArea> areas) =>
      candidates?.areaBytes.entries
          .where((e) => areas.contains(e.key))
          .fold<int>(0, (sum, e) => sum + e.value) ??
      0;
}

/// UI projection of the shown report: a row exists only once its kind is
/// finished and has something to clean, so rows never flash in and out.
List<Reclaimable> storageReclaimables(
  StorageReport? report, {
  required bool syncBusy,
  bool canClean = true,
}) => [
  if (report != null)
    for (final kind in StorageCleanupKind.values)
      if (report.finished(kind) && (report.candidates[kind]?.bytes ?? 0) > 0)
        Reclaimable(
          kind: kind,
          status: AsyncData(report.candidates[kind]!.bytes),
          candidates: report.candidates[kind],
          busy: (kind == .cache || kind == .unusedMedia) && syncBusy,
          enabled: canClean,
        ),
];

class StorageSelectionState {
  final Set<StorageCleanupKind> checked;
  final bool cleaning;

  const StorageSelectionState({
    this.checked = const {
      .retiredModel,
      .unusedModel,
      .partialDownload,
      .cache,
    },
    this.cleaning = false,
  });

  List<Reclaimable> selected(List<Reclaimable> items) =>
      items.where((i) => i.available && checked.contains(i.kind)).toList();

  StorageSelectionState copyWith({
    Set<StorageCleanupKind>? checked,
    bool? cleaning,
  }) => StorageSelectionState(
    checked: checked ?? this.checked,
    cleaning: cleaning ?? this.cleaning,
  );
}

@riverpod
class StorageSelection extends _$StorageSelection {
  @override
  StorageSelectionState build() => const StorageSelectionState();

  void toggle(StorageCleanupKind kind) {
    if (state.cleaning) return;
    final checked = {...state.checked};
    if (!checked.add(kind)) checked.remove(kind);
    state = state.copyWith(checked: checked);
  }

  Future<int> clean(List<Reclaimable> confirmed) async {
    if (state.cleaning ||
        !ref.read(storageDisplayControllerProvider).canClean) {
      return 0;
    }
    final selected = List<Reclaimable>.unmodifiable(confirmed);
    // Immutable candidate lists are captured before any await or refresh.
    state = state.copyWith(cleaning: true);
    var freed = 0;
    final cleaned = <StorageCleanupKind>{};
    try {
      for (final item in selected) {
        bool allowed() =>
            ref.mounted &&
            ref.read(storageDisplayControllerProvider).canClean &&
            item.available &&
            item.candidates != null &&
            (!(item.kind == .cache || item.kind == .unusedMedia) ||
                !ref.read(storageSyncBusyProvider));
        if (!allowed()) continue;
        Future<int> delete() async {
          // Revalidate after waiting for an export/import/sync to release the lock.
          if (!allowed()) return 0;
          cleaned.add(item.kind);
          return switch (item.kind) {
            .retiredModel ||
            .unusedModel ||
            .partialDownload => await _deleteFiles(
              item.candidates!.files,
              partialDownload: item.kind == .partialDownload,
            ),
            .cache => await AppFiles.clearCache(
              filePaths: item.candidates!.files.map((f) => f.path).toSet(),
            ),
            .unusedMedia => await _deleteUnusedMedia(item.candidates!.files),
            .legacyBackup => await LegacyBackups().delete(
              filePaths: item.candidates!.files.map((f) => f.path).toSet(),
            ),
          };
        }

        freed += item.kind == .cache || item.kind == .unusedMedia
            ? await runSyncExclusive(delete)
            : await delete();
      }
      return freed;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(cleaning: false);
        ref
            .read(storageDisplayControllerProvider.notifier)
            .dropCleaned(cleaned);
        ref.invalidate(storageReportProvider);
      }
    }
  }
}

Future<int> _deleteFiles(
  Iterable<StorageCandidate> files, {
  bool partialDownload = false,
}) async {
  var freed = 0;
  for (final file in files) {
    try {
      final stat = await File(file.path).stat();
      if (stat.type != FileSystemEntityType.file) continue;
      if (partialDownload &&
          ((file.modified != null && stat.modified != file.modified) ||
              DateTime.now().difference(stat.modified) <=
                  AppFiles.partialDownloadGrace)) {
        continue;
      }
      if (await AppFiles.deleteFile(file.path)) freed += stat.size;
    } on PathNotFoundException {
      // A download or another cleaner already removed it.
    }
  }
  return freed;
}

Future<int> _deleteUnusedMedia(List<StorageCandidate> files) async {
  // Sync or an editor may have started using a file since the displayed scan.
  final fresh = StorageScanInput(
    referencedMedia: await getIt<DiaryRepository>().collectReferencedMedia(),
  );
  var freed = 0;
  final paths = <String>[];
  for (final file in files.where((f) => !fresh.references(f))) {
    try {
      freed += await File(file.path).length();
      paths.add(file.path);
    } on PathNotFoundException {
      // Already removed.
    }
  }
  await AppFiles.deleteOrphanMedia(
    MediaCleanupReport(paths: paths, bytes: freed),
  );
  return freed;
}
