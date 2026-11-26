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

String _$storageReportHash() => r'd5ad012df6bef318416a0b47dbdcc03c1bb9bc9b';

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

String _$storageSelectionHash() => r'3559d00a24468d99ef25546bd4bf1ba9339b8625';

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
