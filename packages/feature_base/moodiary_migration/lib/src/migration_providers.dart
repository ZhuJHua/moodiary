import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'legacy_data_exporter.dart';
import 'startup_migration_coordinator.dart';

part 'migration_providers.g.dart';

@Riverpod(keepAlive: true)
LegacyDataExporter legacyDataExporter(Ref ref) =>
    throw UnimplementedError('legacyDataExporterProvider must be overridden');

@Riverpod(keepAlive: true)
StartupMigrationCoordinator startupMigrationCoordinator(Ref ref) =>
    StartupMigrationCoordinator();

typedef MigrationGateState = ({bool canStartData, bool canEnterHome});

@Riverpod(keepAlive: true)
class MigrationGate extends _$MigrationGate {
  @override
  MigrationGateState build() {
    final coordinator = ref.watch(startupMigrationCoordinatorProvider);
    void onGateChanged() {
      if (ref.mounted) ref.invalidateSelf();
    }

    coordinator.addGateListener(onGateChanged);
    ref.onDispose(() => coordinator.removeGateListener(onGateChanged));
    return (
      canStartData: coordinator.canStartData,
      canEnterHome: coordinator.canEnterHome,
    );
  }
}
