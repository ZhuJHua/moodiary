// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auto_sync_watcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(autoSyncNextPollAt)
final autoSyncNextPollAtProvider = AutoSyncNextPollAtProvider._();

final class AutoSyncNextPollAtProvider
    extends $FunctionalProvider<DateTime?, DateTime?, DateTime?>
    with $Provider<DateTime?> {
  AutoSyncNextPollAtProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoSyncNextPollAtProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoSyncNextPollAtHash();

  @$internal
  @override
  $ProviderElement<DateTime?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DateTime? create(Ref ref) {
    return autoSyncNextPollAt(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime?>(value),
    );
  }
}

String _$autoSyncNextPollAtHash() =>
    r'e5d3bd7061ca7047daad9c9019d95ba10ba0870e';

@ProviderFor(autoSyncWatcher)
final autoSyncWatcherProvider = AutoSyncWatcherProvider._();

final class AutoSyncWatcherProvider
    extends
        $FunctionalProvider<AutoSyncWatcher, AutoSyncWatcher, AutoSyncWatcher>
    with $Provider<AutoSyncWatcher> {
  AutoSyncWatcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoSyncWatcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoSyncWatcherHash();

  @$internal
  @override
  $ProviderElement<AutoSyncWatcher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AutoSyncWatcher create(Ref ref) {
    return autoSyncWatcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutoSyncWatcher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AutoSyncWatcher>(value),
    );
  }
}

String _$autoSyncWatcherHash() => r'1a55b30d9834917451390c05c2b89b0e1f0e25b3';
