// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_stats_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(syncStats)
final syncStatsProvider = SyncStatsProvider._();

final class SyncStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncStats>,
          SyncStats,
          FutureOr<SyncStats>
        >
    with $FutureModifier<SyncStats>, $FutureProvider<SyncStats> {
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

String _$syncStatsHash() => r'091d327a2bf6015c5a61037b92cd4c2e597fc153';
