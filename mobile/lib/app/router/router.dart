import 'package:moodiary_assistant/moodiary_assistant.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_editor/moodiary_editor.dart' show editorRoutes;
import 'package:moodiary_export/moodiary_export.dart' show exportRoutes;
import 'package:moodiary_lock/moodiary_lock.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart' show mcpRoutes;
import 'package:moodiary_media/moodiary_media.dart' show mediaRoutes;
import 'package:moodiary_migration/moodiary_migration.dart'
    show
        EditorMigrationService,
        LegacyDatabaseGuard,
        LegacyDatabaseState,
        migrationRoutes;
import 'package:moodiary_mobile/app/di/bootstrap.dart' show resumeDataStartup;
import 'package:moodiary_mobile/app/router/route_error_page.dart';
import 'package:moodiary_mobile/app/settings/setting_routes.dart';
import 'package:moodiary_mobile/app/shell/root_shell.dart' show MobileRootShell;
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:mui/mui.dart';

export 'package:moodiary_router/moodiary_router.dart';

final moodiaryNavigationKey = GlobalKey<NavigatorState>();

late final GoRouter router;

void buildRouter({String initialLocation = '/'}) {
  router = createMobileRouter(initialLocation: initialLocation);
}

@visibleForTesting
GoRouter createMobileRouter({
  String initialLocation = '/',
  GlobalKey<NavigatorState>? navigatorKey,
}) => GoRouter(
  routes: _mobileRoutes(),
  initialLocation: initialLocation,
  navigatorKey: navigatorKey ?? moodiaryNavigationKey,
  observers: [FlutterSmartDialog.observer, moodiaryRouteObserver],
  redirect: (context, state) => migrationGateRedirect(state.matchedLocation),
  errorBuilder: (context, state) =>
      RouteErrorPage(uri: state.uri, error: state.error),
);

@visibleForTesting
List<RouteBase> buildMobileRoutes() => _mobileRoutes();

bool isGateRoute(String path) =>
    path == EditorMigrationRoute.path || path == LockRoute.path;

@visibleForTesting
String? migrationGateRedirect(
  String matchedLocation, {
  LegacyDatabaseState? legacyState,
}) {
  if ((legacyState ?? LegacyDatabaseGuard.state) == LegacyDatabaseState.none &&
      !EditorMigrationService.requiresMigration) {
    return null;
  }
  if (isGateRoute(matchedLocation)) {
    return null;
  }
  return EditorMigrationRoute.path;
}

List<RouteBase> _mobileRoutes() => [
  GoRoute(
    path: DiaryHomeRoute.path,
    builder: (_, _) => const MobileRootShell(),
  ),
  ...diaryRoutes(),
  ...mediaRoutes(),
  ...settingRoutes(),
  ...reminderRoutes(),
  ...syncRoutes(),
  ...exportRoutes(),
  ...lockRoutes(),
  ...editorRoutes(),
  ...migrationRoutes(resumeStartup: resumeDataStartup),
  ...mcpRoutes(),
  ...assistantRoutes(),
];
