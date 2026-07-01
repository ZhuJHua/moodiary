// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_stats_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 拉取一次本地 + 远端数据概览。远端只读 `manifest.json`（一次往返），失败不抛出、
/// 以 [SyncStats.remoteError] 呈现，本地数量始终可用。

@ProviderFor(syncStats)
final syncStatsProvider = SyncStatsProvider._();

/// 拉取一次本地 + 远端数据概览。远端只读 `manifest.json`（一次往返），失败不抛出、
/// 以 [SyncStats.remoteError] 呈现，本地数量始终可用。

final class SyncStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncStats>,
          SyncStats,
          FutureOr<SyncStats>
        >
    with $FutureModifier<SyncStats>, $FutureProvider<SyncStats> {
  /// 拉取一次本地 + 远端数据概览。远端只读 `manifest.json`（一次往返），失败不抛出、
  /// 以 [SyncStats.remoteError] 呈现，本地数量始终可用。
  SyncStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncStatsHash();

  @$internal
  @override
  $FutureProviderElement<SyncStats> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<SyncStats> create(Ref ref) {
    return syncStats(ref);
  }
}

String _$syncStatsHash() => r'c4436426b129222a4650e98132560a83bba6b32f';
