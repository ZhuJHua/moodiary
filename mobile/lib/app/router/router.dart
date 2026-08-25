import 'package:moodiary/app/router/route_error_page.dart';
import 'package:moodiary/app/settings/setting_routes.dart';
import 'package:moodiary/app/shell/root_shell.dart' show MobileRootShell;
import 'package:moodiary_assistant/moodiary_assistant.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show EditorMigrationService, editorRoutes;
import 'package:moodiary_export/moodiary_export.dart' show exportRoutes;
import 'package:moodiary_lock/moodiary_lock.dart';
import 'package:moodiary_media/moodiary_media.dart' show mediaRoutes;
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_share/moodiary_share.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:mui/mui.dart';

export 'package:moodiary_assistant/moodiary_assistant.dart'
    show AssistantSettingRoute;
export 'package:moodiary_router/moodiary_router.dart';

final moodiaryNavigationKey = GlobalKey<NavigatorState>();

late final GoRouter router;

void buildRouter({String initialLocation = '/'}) {
  router = createMobileRouter(initialLocation: initialLocation);
}

/// 全局 [router] 是 `late final`，测试里装不了第二次，故把构造单独拆出来。
@visibleForTesting
GoRouter createMobileRouter({
  String initialLocation = '/',
  GlobalKey<NavigatorState>? navigatorKey,
}) => GoRouter(
  routes: _mobileRoutes(),
  initialLocation: initialLocation,
  navigatorKey: navigatorKey ?? moodiaryNavigationKey,
  observers: [FlutterSmartDialog.observer, moodiaryRouteObserver],
  // 强制迁移闸门：存在旧格式日记时，除锁屏外一切目的地重定向到迁移页——首启初始
  // 路由、解锁后的 go('/')、深链全走这里，成功前进不了主界面。
  redirect: (context, state) => migrationGateRedirect(state.matchedLocation),
  // go_router 自带的错误页是英文写死的 MaterialErrorScreen，换成我们自己的。
  errorBuilder: (context, state) =>
      RouteErrorPage(uri: state.uri, error: state.error),
);

@visibleForTesting
List<RouteBase> buildMobileRoutes() => _mobileRoutes();

/// 强制迁移闸门的重定向决策：迁移未完成时只放行锁屏与迁移页本身。
@visibleForTesting
String? migrationGateRedirect(String matchedLocation) {
  if (!EditorMigrationService.requiresMigration) return null;
  if (matchedLocation == EditorMigrationRoute.path ||
      matchedLocation == LockRoute.path) {
    return null;
  }
  return EditorMigrationRoute.path;
}

/// 各 feature 自带路由片段（`xRoutes()`）+ app 侧组合：首页 shell、以及跨 feature 的
/// 助手→选日记页绑定（契约在 moodiary_router / moodiary_assistant，页面归 diary，故 app 绑定）。
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
  ...shareRoutes(),
  ...editorRoutes(),
  ...assistantRoutes(),
  GoRoute(
    path: AssistantDiaryPickerRoute.path,
    builder: (_, _) => const DiarySelectPage(),
  ),
];
