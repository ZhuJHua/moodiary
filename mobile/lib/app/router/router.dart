import 'package:moodiary_assistant/moodiary_assistant.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show EditorMigrationService, editorRoutes;
import 'package:moodiary_export/moodiary_export.dart' show exportRoutes;
import 'package:moodiary_lock/moodiary_lock.dart';
import 'package:moodiary_media/moodiary_media.dart' show mediaRoutes;
import 'package:moodiary_migration/moodiary_migration.dart'
    show EngineMigrationService;
import 'package:moodiary_mobile/app/router/route_error_page.dart';
import 'package:moodiary_mobile/app/settings/setting_routes.dart';
import 'package:moodiary_mobile/app/shell/root_shell.dart' show MobileRootShell;
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

@visibleForTesting
String? migrationGateRedirect(String matchedLocation) {
  if (!EngineMigrationService.requiresMigration &&
      !EditorMigrationService.requiresMigration) {
    return null;
  }
  if (matchedLocation == EditorMigrationRoute.path ||
      matchedLocation == LockRoute.path) {
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
  ...syncRoutes(),
  ...exportRoutes(),
  ...lockRoutes(),
  ...editorRoutes(),
  ...assistantRoutes(),
];
