// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(storageUsage)
final storageUsageProvider = StorageUsageProvider._();

final class StorageUsageProvider
    extends
        $FunctionalProvider<
          AsyncValue<StorageScanProgress>,
          StorageScanProgress,
          Stream<StorageScanProgress>
        >
    with
        $FutureModifier<StorageScanProgress>,
        $StreamProvider<StorageScanProgress> {
  StorageUsageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageUsageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageUsageHash();

  @$internal
  @override
  $StreamProviderElement<StorageScanProgress> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<StorageScanProgress> create(Ref ref) {
    return storageUsage(ref);
  }
}

String _$storageUsageHash() => r'4d992515a74ba4ad8e7e862faeba7efa1795d48f';

@ProviderFor(storageStrayModels)
final storageStrayModelsProvider = StorageStrayModelsProvider._();

final class StorageStrayModelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StrayModelFile>>,
          List<StrayModelFile>,
          FutureOr<List<StrayModelFile>>
        >
    with
        $FutureModifier<List<StrayModelFile>>,
        $FutureProvider<List<StrayModelFile>> {
  StorageStrayModelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageStrayModelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageStrayModelsHash();

  @$internal
  @override
  $FutureProviderElement<List<StrayModelFile>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StrayModelFile>> create(Ref ref) {
    return storageStrayModels(ref);
  }
}

String _$storageStrayModelsHash() =>
    r'443d3b21b1045846e65c1688c8c5e203b40ed0d3';

@ProviderFor(StorageController)
final storageControllerProvider = StorageControllerProvider._();

final class StorageControllerProvider
    extends $NotifierProvider<StorageController, StorageState> {
  StorageControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageControllerHash();

  @$internal
  @override
  StorageController create() => StorageController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StorageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StorageState>(value),
    );
  }
}

String _$storageControllerHash() => r'1f5624fe2ceaa0a46a20679cf218f10a40edfd65';

abstract class _$StorageController extends $Notifier<StorageState> {
  StorageState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<StorageState, StorageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StorageState, StorageState>,
              StorageState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
