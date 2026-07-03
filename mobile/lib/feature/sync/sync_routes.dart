import 'package:go_router/go_router.dart';
import 'package:moodiary_router/moodiary_router.dart';

import 'package:moodiary/feature/sync/presentation/backup_sync_page.dart';
import 'package:moodiary/feature/sync/presentation/sync_log_page.dart';

List<RouteBase> syncRoutes() => [
  GoRoute(
    path: BackupSyncRoute.path,
    builder: (_, _) => const BackupSyncPage(),
  ),
  GoRoute(path: SyncLogRoute.path, builder: (_, _) => const SyncLogPage()),
];
