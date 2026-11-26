// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ml_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(embeddingModelManager)
final embeddingModelManagerProvider = EmbeddingModelManagerProvider._();

final class EmbeddingModelManagerProvider
    extends
        $FunctionalProvider<
          EmbeddingModelManager,
          EmbeddingModelManager,
          EmbeddingModelManager
        >
    with $Provider<EmbeddingModelManager> {
  EmbeddingModelManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'embeddingModelManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$embeddingModelManagerHash();

  @$internal
  @override
  $ProviderElement<EmbeddingModelManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EmbeddingModelManager create(Ref ref) {
    return embeddingModelManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmbeddingModelManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmbeddingModelManager>(value),
    );
  }
}

String _$embeddingModelManagerHash() =>
    r'503d633f080768a2d19047437cce86f19fd48d5d';

@ProviderFor(embeddingBackend)
final embeddingBackendProvider = EmbeddingBackendProvider._();

final class EmbeddingBackendProvider
    extends
        $FunctionalProvider<
          EmbeddingBackend,
          EmbeddingBackend,
          EmbeddingBackend
        >
    with $Provider<EmbeddingBackend> {
  EmbeddingBackendProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'embeddingBackendProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$embeddingBackendHash();

  @$internal
  @override
  $ProviderElement<EmbeddingBackend> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EmbeddingBackend create(Ref ref) {
    return embeddingBackend(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmbeddingBackend value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmbeddingBackend>(value),
    );
  }
}

String _$embeddingBackendHash() => r'185f0a9ca40223c5dfc1744df0fa243201b74ba2';

@ProviderFor(semanticEmbedder)
final semanticEmbedderProvider = SemanticEmbedderProvider._();

final class SemanticEmbedderProvider
    extends
        $FunctionalProvider<
          SemanticEmbedder,
          SemanticEmbedder,
          SemanticEmbedder
        >
    with $Provider<SemanticEmbedder> {
  SemanticEmbedderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'semanticEmbedderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$semanticEmbedderHash();

  @$internal
  @override
  $ProviderElement<SemanticEmbedder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SemanticEmbedder create(Ref ref) {
    return semanticEmbedder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SemanticEmbedder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SemanticEmbedder>(value),
    );
  }
}

String _$semanticEmbedderHash() => r'e517df04e100efb91298c1b6589d94e7a7b581e0';
