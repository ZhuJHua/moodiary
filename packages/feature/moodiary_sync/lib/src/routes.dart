import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_sync/src/presentation/backup_sync_page.dart';
import 'package:moodiary_sync/src/presentation/lan_receive_page.dart';
import 'package:moodiary_sync/src/presentation/lan_send_page.dart';
import 'package:moodiary_sync/src/presentation/sync_log_page.dart';

List<RouteBase> syncRoutes() => [
  MoodiaryGoRoute(
    path: BackupSyncRoute.path,
    builder: (_, _) => const BackupSyncPage(),
  ),
  MoodiaryGoRoute(
    path: SyncLogRoute.path,
    builder: (_, _) => const SyncLogPage(),
  ),
  MoodiaryGoRoute(
    path: LanSendRoute.path,
    builder: (_, _) => const LanSendPage(),
  ),
  MoodiaryGoRoute(
    path: LanReceiveRoute.path,
    builder: (_, _) => const LanReceivePage(),
  ),
];
