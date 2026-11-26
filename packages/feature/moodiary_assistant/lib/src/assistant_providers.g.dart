// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(assistantService)
final assistantServiceProvider = AssistantServiceProvider._();

final class AssistantServiceProvider
    extends
        $FunctionalProvider<
          AssistantService,
          AssistantService,
          AssistantService
        >
    with $Provider<AssistantService> {
  AssistantServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assistantServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assistantServiceHash();

  @$internal
  @override
  $ProviderElement<AssistantService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AssistantService create(Ref ref) {
    return assistantService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AssistantService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AssistantService>(value),
    );
  }
}

String _$assistantServiceHash() => r'aa7f76c7230df13775e53c5c61ce59d6def810ad';

@ProviderFor(chatRepository)
final chatRepositoryProvider = ChatRepositoryProvider._();

final class ChatRepositoryProvider
    extends $FunctionalProvider<ChatRepository, ChatRepository, ChatRepository>
    with $Provider<ChatRepository> {
  ChatRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatRepositoryHash();

  @$internal
  @override
  $ProviderElement<ChatRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatRepository create(Ref ref) {
    return chatRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatRepository>(value),
    );
  }
}

String _$chatRepositoryHash() => r'a27d473b14411a43860b8348d7e674263bd3de40';

@ProviderFor(llmProviderRepository)
final llmProviderRepositoryProvider = LlmProviderRepositoryProvider._();

final class LlmProviderRepositoryProvider
    extends
        $FunctionalProvider<
          LlmProviderRepository,
          LlmProviderRepository,
          LlmProviderRepository
        >
    with $Provider<LlmProviderRepository> {
  LlmProviderRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'llmProviderRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$llmProviderRepositoryHash();

  @$internal
  @override
  $ProviderElement<LlmProviderRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LlmProviderRepository create(Ref ref) {
    return llmProviderRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LlmProviderRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LlmProviderRepository>(value),
    );
  }
}

String _$llmProviderRepositoryHash() =>
    r'619021204e11ff838523fd356d3f93b0a058e45d';

@ProviderFor(llmPresetRepository)
final llmPresetRepositoryProvider = LlmPresetRepositoryProvider._();

final class LlmPresetRepositoryProvider
    extends
        $FunctionalProvider<
          LlmPresetRepository,
          LlmPresetRepository,
          LlmPresetRepository
        >
    with $Provider<LlmPresetRepository> {
  LlmPresetRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'llmPresetRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$llmPresetRepositoryHash();

  @$internal
  @override
  $ProviderElement<LlmPresetRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LlmPresetRepository create(Ref ref) {
    return llmPresetRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LlmPresetRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LlmPresetRepository>(value),
    );
  }
}

String _$llmPresetRepositoryHash() =>
    r'731465216dcc4628ef15d8ddf27945562ee03342';

@ProviderFor(modelCatalogRepository)
final modelCatalogRepositoryProvider = ModelCatalogRepositoryProvider._();

final class ModelCatalogRepositoryProvider
    extends
        $FunctionalProvider<
          ModelCatalogRepository,
          ModelCatalogRepository,
          ModelCatalogRepository
        >
    with $Provider<ModelCatalogRepository> {
  ModelCatalogRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelCatalogRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelCatalogRepositoryHash();

  @$internal
  @override
  $ProviderElement<ModelCatalogRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ModelCatalogRepository create(Ref ref) {
    return modelCatalogRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelCatalogRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelCatalogRepository>(value),
    );
  }
}

String _$modelCatalogRepositoryHash() =>
    r'e4a86b9c9da99eb156037eccfa2eb3ed9a2e8e62';

@ProviderFor(memoryRepository)
final memoryRepositoryProvider = MemoryRepositoryProvider._();

final class MemoryRepositoryProvider
    extends
        $FunctionalProvider<
          MemoryRepository,
          MemoryRepository,
          MemoryRepository
        >
    with $Provider<MemoryRepository> {
  MemoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<MemoryRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MemoryRepository create(Ref ref) {
    return memoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryRepository>(value),
    );
  }
}

String _$memoryRepositoryHash() => r'0793b87a0eb80c6e663cdc36018203b5e4d485fc';
