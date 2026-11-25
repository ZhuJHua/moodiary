library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/editor_migration_page.dart';

export 'src/editor_migration_page.dart';
export 'src/editor_migration_service.dart';
export 'src/legacy_backups.dart';
export 'src/legacy_data_exporter.dart';
export 'src/legacy_database_guard.dart';
export 'src/migration_providers.dart';
export 'src/startup_migration_coordinator.dart';
export 'src/version_migrator.dart';

List<RouteBase> migrationRoutes({
  required Future<void> Function() resumeStartup,
}) => [
  GoRoute(
    path: EditorMigrationRoute.path,
    builder: (_, _) => EditorMigrationPage(resumeStartup: resumeStartup),
  ),
];
