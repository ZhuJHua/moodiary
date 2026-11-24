// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(storageReport)
final storageReportProvider = StorageReportProvider._();

final class StorageReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<StorageReport>,
          StorageReport,
          Stream<StorageReport>
        >
    with $FutureModifier<StorageReport>, $StreamProvider<StorageReport> {
  StorageReportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageReportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageReportHash();

  @$internal
  @override
  $StreamProviderElement<StorageReport> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<StorageReport> create(Ref ref) {
    return storageReport(ref);
  }
}

String _$storageReportHash() => r'09d393344c0e5ca545f8bceffeb2bccfeae5b615';

/// Rescans keep the last finished report on screen until the new scan completes.

@ProviderFor(StorageDisplayController)
final storageDisplayControllerProvider = StorageDisplayControllerProvider._();

/// Rescans keep the last finished report on screen until the new scan completes.
final class StorageDisplayControllerProvider
    extends $NotifierProvider<StorageDisplayController, StorageDisplay> {
  /// Rescans keep the last finished report on screen until the new scan completes.
  StorageDisplayControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageDisplayControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageDisplayControllerHash();

  @$internal
  @override
  StorageDisplayController create() => StorageDisplayController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StorageDisplay value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StorageDisplay>(value),
    );
  }
}

String _$storageDisplayControllerHash() =>
    r'ab359c6410f4ca7e0c8f47f3af9636eeb5588c6f';

/// Rescans keep the last finished report on screen until the new scan completes.

abstract class _$StorageDisplayController extends $Notifier<StorageDisplay> {
  StorageDisplay build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<StorageDisplay, StorageDisplay>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StorageDisplay, StorageDisplay>,
              StorageDisplay,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

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

String _$storageSelectionHash() => r'464ad37c96f94d0bc06dd675d42e1f8f25ff1d96';

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
