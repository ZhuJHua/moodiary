import 'package:moodiary/app/router/route_error_page.dart';
import 'package:moodiary/app/settings/setting_routes.dart';
import 'package:moodiary/app/shell/root_shell.dart' show MobileRootShell;
import 'package:moodiary_assistant/moodiary_assistant.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_editor/moodiary_editor.dart' show editorRoutes;
import 'package:moodiary_export/moodiary_export.dart' show exportRoutes;
import 'package:moodiary_lock/moodiary_lock.dart';
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
  // errorPageBuilder 而不是 errorBuilder：后者交给 go_router 包 Page，会落到没有
  // 转场的那条分支（同 MoodiaryGoRoute 的原因）。
  errorPageBuilder: (context, state) => MaterialPage(
    key: state.pageKey,
    child: RouteErrorPage(uri: state.uri, error: state.error),
  ),
);

@visibleForTesting
List<RouteBase> buildMobileRoutes() => _mobileRoutes();

/// 各 feature 自带路由片段（`xRoutes()`）+ app 侧组合：首页 shell、以及跨 feature 的
/// 助手→选日记页绑定（契约在 moodiary_router / moodiary_assistant，页面归 diary，故 app 绑定）。
List<RouteBase> _mobileRoutes() => [
  MoodiaryGoRoute(
    path: DiaryHomeRoute.path,
    builder: (_, _) => const MobileRootShell(),
  ),
  ...diaryRoutes(),
  ...settingRoutes(),
  ...syncRoutes(),
  ...exportRoutes(),
  ...lockRoutes(),
  ...shareRoutes(),
  ...editorRoutes(),
  ...assistantRoutes(),
  MoodiaryGoRoute(
    path: AssistantDiaryPickerRoute.path,
    builder: (_, _) => const DiarySelectPage(),
  ),
];
