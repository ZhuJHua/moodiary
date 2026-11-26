// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(syncLoggerAsync)
final syncLoggerAsyncProvider = SyncLoggerAsyncProvider._();

final class SyncLoggerAsyncProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncLogger>,
          SyncLogger,
          FutureOr<SyncLogger>
        >
    with $FutureModifier<SyncLogger>, $FutureProvider<SyncLogger> {
  SyncLoggerAsyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncLoggerAsyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncLoggerAsyncHash();

  @$internal
  @override
  $FutureProviderElement<SyncLogger> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<SyncLogger> create(Ref ref) {
    return syncLoggerAsync(ref);
  }
}

String _$syncLoggerAsyncHash() => r'c1e3e5c3c23f75b5f445de0fa9dd46311beac5ad';

@ProviderFor(syncLogger)
final syncLoggerProvider = SyncLoggerProvider._();

final class SyncLoggerProvider
    extends $FunctionalProvider<SyncLogger, SyncLogger, SyncLogger>
    with $Provider<SyncLogger> {
  SyncLoggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncLoggerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncLoggerHash();

  @$internal
  @override
  $ProviderElement<SyncLogger> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncLogger create(Ref ref) {
    return syncLogger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncLogger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncLogger>(value),
    );
  }
}

String _$syncLoggerHash() => r'40b1c7d7eedba4dc9f831a0e14ea1f3e577bdb5e';

@ProviderFor(syncOperationGuard)
final syncOperationGuardProvider = SyncOperationGuardProvider._();

final class SyncOperationGuardProvider
    extends
        $FunctionalProvider<
          SyncOperationGuard,
          SyncOperationGuard,
          SyncOperationGuard
        >
    with $Provider<SyncOperationGuard> {
  SyncOperationGuardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncOperationGuardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncOperationGuardHash();

  @$internal
  @override
  $ProviderElement<SyncOperationGuard> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncOperationGuard create(Ref ref) {
    return syncOperationGuard(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncOperationGuard value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncOperationGuard>(value),
    );
  }
}

String _$syncOperationGuardHash() =>
    r'd302dd8e2334860cf21af506842204c3b94661a5';

@ProviderFor(syncOperationBusy)
final syncOperationBusyProvider = SyncOperationBusyProvider._();

final class SyncOperationBusyProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  SyncOperationBusyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncOperationBusyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncOperationBusyHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return syncOperationBusy(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$syncOperationBusyHash() => r'3ab322e3a61e0ad580a0355c090547db112fd6bc';

@ProviderFor(ActiveSyncProviderType)
final activeSyncProviderTypeProvider = ActiveSyncProviderTypeProvider._();

final class ActiveSyncProviderTypeProvider
    extends $NotifierProvider<ActiveSyncProviderType, SyncProviderType> {
  ActiveSyncProviderTypeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeSyncProviderTypeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeSyncProviderTypeHash();

  @$internal
  @override
  ActiveSyncProviderType create() => ActiveSyncProviderType();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncProviderType value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncProviderType>(value),
    );
  }
}

String _$activeSyncProviderTypeHash() =>
    r'aabcf09cce7bbaf11230c28d6ab6690d64596432';

abstract class _$ActiveSyncProviderType extends $Notifier<SyncProviderType> {
  SyncProviderType build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SyncProviderType, SyncProviderType>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncProviderType, SyncProviderType>,
              SyncProviderType,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(syncSecureOptions)
final syncSecureOptionsProvider = SyncSecureOptionsFamily._();

final class SyncSecureOptionsProvider
    extends $FunctionalProvider<SecureOptions, SecureOptions, SecureOptions>
    with $Provider<SecureOptions> {
  SyncSecureOptionsProvider._({
    required SyncSecureOptionsFamily super.from,
    required SyncProviderType super.argument,
  }) : super(
         retry: null,
         name: r'syncSecureOptionsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$syncSecureOptionsHash();

  @override
  String toString() {
    return r'syncSecureOptionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<SecureOptions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecureOptions create(Ref ref) {
    final argument = this.argument as SyncProviderType;
    return syncSecureOptions(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureOptions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureOptions>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SyncSecureOptionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$syncSecureOptionsHash() => r'8afa791413f106fedbb09da1a255bdcf8c875673';

final class SyncSecureOptionsFamily extends $Family
    with $FunctionalFamilyOverride<SecureOptions, SyncProviderType> {
  SyncSecureOptionsFamily._()
    : super(
        retry: null,
        name: r'syncSecureOptionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SyncSecureOptionsProvider call(SyncProviderType type) =>
      SyncSecureOptionsProvider._(argument: type, from: this);

  @override
  String toString() => r'syncSecureOptionsProvider';
}

@ProviderFor(syncBackend)
final syncBackendProvider = SyncBackendFamily._();

final class SyncBackendProvider
    extends
        $FunctionalProvider<
          IRemoteSyncBackend,
          IRemoteSyncBackend,
          IRemoteSyncBackend
        >
    with $Provider<IRemoteSyncBackend> {
  SyncBackendProvider._({
    required SyncBackendFamily super.from,
    required SyncProviderType super.argument,
  }) : super(
         retry: null,
         name: r'syncBackendProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$syncBackendHash();

  @override
  String toString() {
    return r'syncBackendProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<IRemoteSyncBackend> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IRemoteSyncBackend create(Ref ref) {
    final argument = this.argument as SyncProviderType;
    return syncBackend(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IRemoteSyncBackend value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IRemoteSyncBackend>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SyncBackendProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$syncBackendHash() => r'4aaf8d823789d7583c3d8ab6b0c2425aae25410f';

final class SyncBackendFamily extends $Family
    with $FunctionalFamilyOverride<IRemoteSyncBackend, SyncProviderType> {
  SyncBackendFamily._()
    : super(
        retry: null,
        name: r'syncBackendProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SyncBackendProvider call(SyncProviderType type) =>
      SyncBackendProvider._(argument: type, from: this);

  @override
  String toString() => r'syncBackendProvider';
}

@ProviderFor(activeSyncBackend)
final activeSyncBackendProvider = ActiveSyncBackendProvider._();

final class ActiveSyncBackendProvider
    extends
        $FunctionalProvider<
          IRemoteSyncBackend,
          IRemoteSyncBackend,
          IRemoteSyncBackend
        >
    with $Provider<IRemoteSyncBackend> {
  ActiveSyncBackendProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeSyncBackendProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeSyncBackendHash();

  @$internal
  @override
  $ProviderElement<IRemoteSyncBackend> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IRemoteSyncBackend create(Ref ref) {
    return activeSyncBackend(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IRemoteSyncBackend value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IRemoteSyncBackend>(value),
    );
  }
}

String _$activeSyncBackendHash() => r'5a3c9f8686d26bcb911bd97861c3b9364b170894';

@ProviderFor(syncBackendReady)
final syncBackendReadyProvider = SyncBackendReadyProvider._();

final class SyncBackendReadyProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  SyncBackendReadyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncBackendReadyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncBackendReadyHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return syncBackendReady(ref);
  }
}

String _$syncBackendReadyHash() => r'abad77f6e73654fbb814fe84f8b51f57173fdd23';

@ProviderFor(configuredCloudBackendIds)
final configuredCloudBackendIdsProvider = ConfiguredCloudBackendIdsProvider._();

final class ConfiguredCloudBackendIdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          FutureOr<Set<String>>
        >
    with $FutureModifier<Set<String>>, $FutureProvider<Set<String>> {
  ConfiguredCloudBackendIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'configuredCloudBackendIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$configuredCloudBackendIdsHash();

  @$internal
  @override
  $FutureProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<String>> create(Ref ref) {
    return configuredCloudBackendIds(ref);
  }
}

String _$configuredCloudBackendIdsHash() =>
    r'fecf9529aab59fd6ee151ec2f141839477f7a890';

@ProviderFor(syncArchiveStores)
final syncArchiveStoresProvider = SyncArchiveStoresProvider._();

final class SyncArchiveStoresProvider
    extends $FunctionalProvider<ArchiveStores, ArchiveStores, ArchiveStores>
    with $Provider<ArchiveStores> {
  SyncArchiveStoresProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncArchiveStoresProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncArchiveStoresHash();

  @$internal
  @override
  $ProviderElement<ArchiveStores> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ArchiveStores create(Ref ref) {
    return syncArchiveStores(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArchiveStores value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArchiveStores>(value),
    );
  }
}

String _$syncArchiveStoresHash() => r'747ff1c208103d45939e09530629ed93ec54936d';

@ProviderFor(localArchive)
final localArchiveProvider = LocalArchiveProvider._();

final class LocalArchiveProvider
    extends $FunctionalProvider<LocalArchive, LocalArchive, LocalArchive>
    with $Provider<LocalArchive> {
  LocalArchiveProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localArchiveProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localArchiveHash();

  @$internal
  @override
  $ProviderElement<LocalArchive> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalArchive create(Ref ref) {
    return localArchive(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalArchive value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalArchive>(value),
    );
  }
}

String _$localArchiveHash() => r'1bf81e1a0d4ab6318dc4871603c45fb0f18ae354';
