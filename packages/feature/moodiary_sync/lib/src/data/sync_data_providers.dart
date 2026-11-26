import 'dart:async';
import 'dart:convert';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/sync_controller.dart';
import '../application/sync_operation_guard.dart';
import 'impl/local_archive.dart';
import 'impl/s3_sync.dart';
import 'impl/webdav_sync.dart';
import 'model/sync_provider.dart';
import 'remote_lease.dart';
import 'sync.dart';
import 'sync_key_manager.dart';
import 'sync_logger.dart';
import 'sync_stores.dart';

part 'secure_options.dart';
part 'sync_data_providers.g.dart';

@Riverpod(keepAlive: true)
Future<SyncLogger> syncLoggerAsync(Ref ref) async {
  final logger = await SyncLogger.create();
  if (ref.mounted) {
    ref.onDispose(() => unawaited(logger.dispose()));
  } else {
    await logger.dispose();
  }
  return logger;
}

@Riverpod(keepAlive: true)
SyncLogger syncLogger(Ref ref) =>
    ref.watch(syncLoggerAsyncProvider).requireValue;

@Riverpod(keepAlive: true)
SyncOperationGuard syncOperationGuard(Ref ref) {
  final guard = SyncOperationGuard();
  ref.onDispose(() => unawaited(guard.dispose()));
  return guard;
}

@riverpod
bool syncOperationBusy(Ref ref) {
  final guard = ref.watch(syncOperationGuardProvider);
  final subscription = guard.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(() => unawaited(subscription.cancel()));
  return guard.isBusy;
}

@Riverpod(keepAlive: true)
class ActiveSyncProviderType extends _$ActiveSyncProviderType {
  @override
  SyncProviderType build() =>
      SyncProviderType.fromValue(MoodiaryKVs.syncProvider.get());

  bool select(SyncProviderType type) {
    final operation = ref.read(syncOperationGuardProvider).tryAcquire();
    if (operation == null) return false;
    try {
      MoodiaryKVs.syncProvider.set(type.value);
      RemoteLease.resetCasProbeCache();
      ref.read(syncControllerProvider.notifier).resetHealth();
      state = type;
      return true;
    } finally {
      operation.release();
    }
  }

  Future<bool> saveOptions(SyncProviderType type, List<String> options) =>
      _configure(type, options);
  Future<bool> clearOptions(SyncProviderType type) => _configure(type, null);

  Future<bool> _configure(SyncProviderType type, List<String>? options) async {
    final operation = ref.read(syncOperationGuardProvider).tryAcquire();
    if (operation == null) return false;
    try {
      final store = ref.read(syncSecureOptionsProvider(type));
      if (options == null) {
        await store._clear();
      } else {
        if (await SyncKeyManager.loadDek() != null) {
          await SyncKeyManager.markPendingUpload([type.value]);
        }
        await store._save(options);
      }
      MoodiaryKVs.syncManifestStat.remove();
      ref.invalidate(syncBackendProvider(type));
      RemoteLease.resetCasProbeCache();
      ref.invalidate(configuredCloudBackendIdsProvider);
      if (type == state) {
        ref.read(syncControllerProvider.notifier).resetHealth();
      }
      return true;
    } finally {
      operation.release();
    }
  }
}

@Riverpod(keepAlive: true)
SecureOptions syncSecureOptions(Ref ref, SyncProviderType type) =>
    SecureOptions(switch (type) {
      .webdav => .webDavOption,
      .s3 => .s3Option,
    }, ref.watch(secureKvStorageProvider));

@Riverpod(keepAlive: true)
IRemoteSyncBackend syncBackend(Ref ref, SyncProviderType type) {
  final options = ref.watch(syncSecureOptionsProvider(type));
  return switch (type) {
    .webdav => WebDavSyncBackend(options.read()),
    .s3 => S3SyncBackend(options.read()),
  };
}

@Riverpod(keepAlive: true)
IRemoteSyncBackend activeSyncBackend(Ref ref) =>
    ref.watch(syncBackendProvider(ref.watch(activeSyncProviderTypeProvider)));

@riverpod
Future<bool> syncBackendReady(Ref ref) =>
    ref.watch(activeSyncBackendProvider).isReady();

@riverpod
Future<Set<String>> configuredCloudBackendIds(Ref ref) async {
  final backends = [
    for (final type in SyncProviderType.values)
      ref.watch(syncBackendProvider(type)),
  ];
  final link = ref.keepAlive();
  try {
    return {
      for (final backend in backends)
        if (await backend.isReady()) ?backend.persistentBackendId,
    };
  } finally {
    link.close();
  }
}

@Riverpod(keepAlive: true)
ArchiveStores syncArchiveStores(Ref ref) => (
  diaries: RepoSyncDiaryStore(ref.watch(diaryRepositoryProvider)),
  categories: RepoSyncCategoryStore(ref.watch(categoryRepositoryProvider)),
  tags: RepoSyncTagStore(ref.watch(tagRepositoryProvider)),
  places: RepoSyncPlaceStore(ref.watch(placeRepositoryProvider)),
  tombstones: RepoSyncTombstoneStore(ref.watch(tombstoneRepositoryProvider)),
);

@Riverpod(keepAlive: true)
LocalArchive localArchive(Ref ref) => LocalArchive(
  ref.watch(syncArchiveStoresProvider),
  ref.watch(syncLoggerProvider),
  ref.watch(openDiaryRegistryProvider),
  ref.watch(syncPendingStateProvider.notifier),
);
