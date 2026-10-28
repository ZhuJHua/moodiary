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

@ProviderFor(storageOrphanMedia)
final storageOrphanMediaProvider = StorageOrphanMediaProvider._();

final class StorageOrphanMediaProvider
    extends
        $FunctionalProvider<
          AsyncValue<StorageOrphanMedia>,
          StorageOrphanMedia,
          FutureOr<StorageOrphanMedia>
        >
    with
        $FutureModifier<StorageOrphanMedia>,
        $FutureProvider<StorageOrphanMedia> {
  StorageOrphanMediaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageOrphanMediaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageOrphanMediaHash();

  @$internal
  @override
  $FutureProviderElement<StorageOrphanMedia> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<StorageOrphanMedia> create(Ref ref) {
    return storageOrphanMedia(ref);
  }
}

String _$storageOrphanMediaHash() =>
    r'f09958e228fd9dd8b00d77f2086f18f6f2e94630';

@ProviderFor(storageLegacyBackups)
final storageLegacyBackupsProvider = StorageLegacyBackupsProvider._();

final class StorageLegacyBackupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<StorageLegacyBackups>,
          StorageLegacyBackups,
          FutureOr<StorageLegacyBackups>
        >
    with
        $FutureModifier<StorageLegacyBackups>,
        $FutureProvider<StorageLegacyBackups> {
  StorageLegacyBackupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageLegacyBackupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageLegacyBackupsHash();

  @$internal
  @override
  $FutureProviderElement<StorageLegacyBackups> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<StorageLegacyBackups> create(Ref ref) {
    return storageLegacyBackups(ref);
  }
}

String _$storageLegacyBackupsHash() =>
    r'6c4692f72988c7efb487c811558ac31fa21e09a0';

@ProviderFor(storageCacheReclaim)
final storageCacheReclaimProvider = StorageCacheReclaimProvider._();

final class StorageCacheReclaimProvider
    extends
        $FunctionalProvider<AsyncValue<int>, AsyncValue<int>, AsyncValue<int>>
    with $Provider<AsyncValue<int>> {
  StorageCacheReclaimProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageCacheReclaimProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageCacheReclaimHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AsyncValue<int> create(Ref ref) {
    return storageCacheReclaim(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<int>>(value),
    );
  }
}

String _$storageCacheReclaimHash() =>
    r'3d34a297fa6c26616b4b89601242a36696547d06';

@ProviderFor(storageSyncBusy)
final storageSyncBusyProvider = StorageSyncBusyProvider._();

final class StorageSyncBusyProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  StorageSyncBusyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageSyncBusyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageSyncBusyHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return storageSyncBusy(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$storageSyncBusyHash() => r'3dbd6bb3499e935de3edad0a66be1f1413c3118f';

@ProviderFor(storageReclaimables)
final storageReclaimablesProvider = StorageReclaimablesProvider._();

final class StorageReclaimablesProvider
    extends
        $FunctionalProvider<
          List<Reclaimable>,
          List<Reclaimable>,
          List<Reclaimable>
        >
    with $Provider<List<Reclaimable>> {
  StorageReclaimablesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageReclaimablesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageReclaimablesHash();

  @$internal
  @override
  $ProviderElement<List<Reclaimable>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<Reclaimable> create(Ref ref) {
    return storageReclaimables(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Reclaimable> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Reclaimable>>(value),
    );
  }
}

String _$storageReclaimablesHash() =>
    r'0f3afdaeffde48a25a752d177187c808f7838ffd';

@ProviderFor(StorageSelection)
final storageSelectionProvider = StorageSelectionProvider._();

final class StorageSelectionProvider
    extends $NotifierProvider<StorageSelection, StorageSelectionState> {
  StorageSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageSelectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageSelectionHash();

  @$internal
  @override
  StorageSelection create() => StorageSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StorageSelectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StorageSelectionState>(value),
    );
  }
}

String _$storageSelectionHash() => r'f4c86c37ef3d1bc91e5d859c1900b3293641b4aa';

abstract class _$StorageSelection extends $Notifier<StorageSelectionState> {
  StorageSelectionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<StorageSelectionState, StorageSelectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StorageSelectionState, StorageSelectionState>,
              StorageSelectionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
