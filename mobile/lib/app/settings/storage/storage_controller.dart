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
  final StorageCandidates? candidates;

  const Reclaimable({
    required this.kind,
    required this.status,
    this.busy = false,
    this.candidates,
  });

  ReclaimSafety get safety => switch (kind) {
    .unusedMedia || .legacyBackup => .careful,
    _ => .safe,
  };
  Map<MediaType, int> get counts => candidates?.counts ?? const {};
  int get bytes => status.value ?? 0;
  bool get available =>
      !status.isLoading && !status.hasError && !busy && bytes > 0;
  int bytesIn(Iterable<StorageArea> areas) =>
      candidates?.areaBytes.entries
          .where((e) => areas.contains(e.key))
          .fold<int>(0, (sum, e) => sum + e.value) ??
      0;
}

/// UI projection of the one report; no additional asynchronous sources.
List<Reclaimable> storageReclaimables(
  AsyncValue<StorageReport> report, {
  required bool syncBusy,
}) =>
    [
          for (final kind in StorageCleanupKind.values)
            Reclaimable(
              kind: kind,
              status: report.when(
                skipLoadingOnRefresh: false,
                data: (value) => value.finished(kind)
                    ? AsyncData(value.candidates[kind]?.bytes ?? 0)
                    : const AsyncLoading(),
                error: AsyncError.new,
                loading: () => const AsyncLoading(),
              ),
              candidates: report.isLoading || report.hasError
                  ? null
                  : report.value?.candidates[kind],
              busy: kind == .cache && syncBusy,
            ),
        ]
        .where(
          (item) =>
              item.status.isLoading || item.status.hasError || item.bytes > 0,
        )
        .toList();

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

  Future<int> clean() async {
    if (state.cleaning) return 0;
    final selected = state.selected(
      storageReclaimables(
        ref.read(storageReportProvider),
        syncBusy: ref.read(storageSyncBusyProvider),
      ),
    );
    // Immutable candidate lists are captured before any await or refresh.
    state = state.copyWith(cleaning: true);
    var freed = 0;
    try {
      for (final item in selected) {
        if (item.kind == .cache && ref.read(storageSyncBusyProvider)) continue;
        freed += switch (item.kind) {
          .retiredModel ||
          .unusedModel ||
          .partialDownload => await _deleteFiles(item.candidates!.files),
          .cache => await AppFiles.clearCache(
            filePaths: item.candidates!.files.map((f) => f.path).toSet(),
          ),
          .unusedMedia => await _deleteUnusedMedia(item.candidates!.files),
          .legacyBackup => await LegacyBackups().delete(
            filePaths: item.candidates!.files.map((f) => f.path).toSet(),
          ),
        };
      }
      return freed;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(cleaning: false);
        ref.invalidate(storageReportProvider);
      }
    }
  }
}

Future<int> _deleteFiles(Iterable<StorageCandidate> files) async {
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
