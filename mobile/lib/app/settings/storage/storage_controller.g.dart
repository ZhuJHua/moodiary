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

String _$storageReportHash() => r'6582af7360fcb559306a9b1dce9243bd905ffe4f';

/// Rescans (after a clean, or coming back from a linked page) keep the last
/// finished report on screen and swap it only when the new scan is done, so
/// rows and sizes don't drop to zero and grow back.

@ProviderFor(StorageDisplayController)
final storageDisplayControllerProvider = StorageDisplayControllerProvider._();

/// Rescans (after a clean, or coming back from a linked page) keep the last
/// finished report on screen and swap it only when the new scan is done, so
/// rows and sizes don't drop to zero and grow back.
final class StorageDisplayControllerProvider
    extends $NotifierProvider<StorageDisplayController, StorageDisplay> {
  /// Rescans (after a clean, or coming back from a linked page) keep the last
  /// finished report on screen and swap it only when the new scan is done, so
  /// rows and sizes don't drop to zero and grow back.
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

/// Rescans (after a clean, or coming back from a linked page) keep the last
/// finished report on screen and swap it only when the new scan is done, so
/// rows and sizes don't drop to zero and grow back.

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

String _$storageSelectionHash() => r'4db64bb6c8957f782671a085e7cba57e8b7550c5';

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
