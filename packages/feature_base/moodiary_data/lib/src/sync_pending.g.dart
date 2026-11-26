// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_pending.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SyncPendingTracker)
final syncPendingStateProvider = SyncPendingTrackerProvider._();

final class SyncPendingTrackerProvider
    extends $NotifierProvider<SyncPendingTracker, SyncPendingState> {
  SyncPendingTrackerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncPendingStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncPendingTrackerHash();

  @$internal
  @override
  SyncPendingTracker create() => SyncPendingTracker();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncPendingState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncPendingState>(value),
    );
  }
}

String _$syncPendingTrackerHash() =>
    r'fcc117e125019ae9b5f2a916163711e4184fc914';

abstract class _$SyncPendingTracker extends $Notifier<SyncPendingState> {
  SyncPendingState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SyncPendingState, SyncPendingState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncPendingState, SyncPendingState>,
              SyncPendingState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(SyncDirtyTracker)
final syncDirtyDiaryIdsProvider = SyncDirtyTrackerProvider._();

final class SyncDirtyTrackerProvider
    extends $NotifierProvider<SyncDirtyTracker, Set<String>> {
  SyncDirtyTrackerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncDirtyDiaryIdsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncDirtyTrackerHash();

  @$internal
  @override
  SyncDirtyTracker create() => SyncDirtyTracker();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$syncDirtyTrackerHash() => r'840496a8a468b5c18efba449a2e230497e4d2c62';

abstract class _$SyncDirtyTracker extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
