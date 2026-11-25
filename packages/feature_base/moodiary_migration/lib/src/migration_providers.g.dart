// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'migration_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(legacyDataExporter)
final legacyDataExporterProvider = LegacyDataExporterProvider._();

final class LegacyDataExporterProvider
    extends
        $FunctionalProvider<
          LegacyDataExporter,
          LegacyDataExporter,
          LegacyDataExporter
        >
    with $Provider<LegacyDataExporter> {
  LegacyDataExporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'legacyDataExporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$legacyDataExporterHash();

  @$internal
  @override
  $ProviderElement<LegacyDataExporter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LegacyDataExporter create(Ref ref) {
    return legacyDataExporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LegacyDataExporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LegacyDataExporter>(value),
    );
  }
}

String _$legacyDataExporterHash() =>
    r'1a593a03492e0c70d508598a4c5392f08f26b818';

@ProviderFor(startupMigrationCoordinator)
final startupMigrationCoordinatorProvider =
    StartupMigrationCoordinatorProvider._();

final class StartupMigrationCoordinatorProvider
    extends
        $FunctionalProvider<
          StartupMigrationCoordinator,
          StartupMigrationCoordinator,
          StartupMigrationCoordinator
        >
    with $Provider<StartupMigrationCoordinator> {
  StartupMigrationCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'startupMigrationCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$startupMigrationCoordinatorHash();

  @$internal
  @override
  $ProviderElement<StartupMigrationCoordinator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StartupMigrationCoordinator create(Ref ref) {
    return startupMigrationCoordinator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StartupMigrationCoordinator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StartupMigrationCoordinator>(value),
    );
  }
}

String _$startupMigrationCoordinatorHash() =>
    r'8e8ae22f283eb1c6c806c6a5f0a81a2f56c59675';

@ProviderFor(MigrationGate)
final migrationGateProvider = MigrationGateProvider._();

final class MigrationGateProvider
    extends $NotifierProvider<MigrationGate, MigrationGateState> {
  MigrationGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'migrationGateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$migrationGateHash();

  @$internal
  @override
  MigrationGate create() => MigrationGate();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MigrationGateState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MigrationGateState>(value),
    );
  }
}

String _$migrationGateHash() => r'3de895a5ea1563bcd3fddf9c057b24130a83bfa2';

abstract class _$MigrationGate extends $Notifier<MigrationGateState> {
  MigrationGateState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MigrationGateState, MigrationGateState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MigrationGateState, MigrationGateState>,
              MigrationGateState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
