import 'package:moodiary_assistant/moodiary_assistant.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_editor/moodiary_editor.dart' show editorRoutes;
import 'package:moodiary_export/moodiary_export.dart' show exportRoutes;
import 'package:moodiary_lock/moodiary_lock.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart' show mcpRoutes;
import 'package:moodiary_media/moodiary_media.dart' show mediaRoutes;
import 'package:moodiary_migration/moodiary_migration.dart'
    show migrationGateProvider, migrationRoutes;
import 'package:moodiary_mobile/app/di/bootstrap.dart' show resumeDataStartup;
import 'package:moodiary_mobile/app/router/route_error_page.dart';
import 'package:moodiary_mobile/app/settings/setting_routes.dart';
import 'package:moodiary_mobile/app/shell/root_shell.dart' show MobileRootShell;
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:mui/mui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:moodiary_router/moodiary_router.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = createMobileRouter(
    initialLocation: ref.read(appLockEnabledProvider)
        ? LockRoute.path
        : DiaryHomeRoute.path,
    canEnterHome: () => ref.read(migrationGateProvider).canEnterHome,
    resumeStartup: () => resumeDataStartup(ref),
  );
  ref.onDispose(router.dispose);
  return router;
}

@visibleForTesting
GoRouter createMobileRouter({
  String initialLocation = '/',
  required bool Function() canEnterHome,
  required Future<void> Function() resumeStartup,
  GlobalKey<NavigatorState>? navigatorKey,
}) => GoRouter(
  routes: buildMobileRoutes(resumeStartup: resumeStartup),
  initialLocation: initialLocation,
  navigatorKey: navigatorKey,
  observers: [FlutterSmartDialog.observer, moodiaryRouteObserver],
  redirect: (context, state) => migrationGateRedirect(
    state.matchedLocation,
    canEnterHome: canEnterHome(),
  ),
  errorBuilder: (context, state) =>
      RouteErrorPage(uri: state.uri, error: state.error),
);

bool isGateRoute(String path) =>
    path == EditorMigrationRoute.path || path == LockRoute.path;

@visibleForTesting
String? migrationGateRedirect(
  String matchedLocation, {
  required bool canEnterHome,
}) {
  if (canEnterHome) {
    return null;
  }
  if (isGateRoute(matchedLocation)) {
    return null;
  }
  return EditorMigrationRoute.path;
}

@visibleForTesting
List<RouteBase> buildMobileRoutes({
  required Future<void> Function() resumeStartup,
}) => [
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
  ...migrationRoutes(resumeStartup: resumeStartup),
  ...mcpRoutes(),
  ...assistantRoutes(),
];
