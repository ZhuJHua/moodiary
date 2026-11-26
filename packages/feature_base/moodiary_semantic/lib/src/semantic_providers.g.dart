// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'semantic_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(embedIndexService)
final embedIndexServiceProvider = EmbedIndexServiceProvider._();

final class EmbedIndexServiceProvider
    extends
        $FunctionalProvider<
          EmbedIndexService,
          EmbedIndexService,
          EmbedIndexService
        >
    with $Provider<EmbedIndexService> {
  EmbedIndexServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'embedIndexServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$embedIndexServiceHash();

  @$internal
  @override
  $ProviderElement<EmbedIndexService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EmbedIndexService create(Ref ref) {
    return embedIndexService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmbedIndexService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmbedIndexService>(value),
    );
  }
}

String _$embedIndexServiceHash() => r'4f9eda0e212ad480bfcdf9bc7d9a81e139fbc20a';

@ProviderFor(embedQueueWatcher)
final embedQueueWatcherProvider = EmbedQueueWatcherProvider._();

final class EmbedQueueWatcherProvider
    extends
        $FunctionalProvider<
          EmbedQueueWatcher,
          EmbedQueueWatcher,
          EmbedQueueWatcher
        >
    with $Provider<EmbedQueueWatcher> {
  EmbedQueueWatcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'embedQueueWatcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$embedQueueWatcherHash();

  @$internal
  @override
  $ProviderElement<EmbedQueueWatcher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EmbedQueueWatcher create(Ref ref) {
    return embedQueueWatcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmbedQueueWatcher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmbedQueueWatcher>(value),
    );
  }
}

String _$embedQueueWatcherHash() => r'f548fcfa128e85175b535f8633527a14be7fbaef';
