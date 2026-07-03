import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart';

import 'package:moodiary/app/shell/root_shell.dart' show MobileRootShell;
import 'package:moodiary/feature/diary/diary_routes.dart';
import 'package:moodiary/feature/diary/presentation/diary_select_page.dart';
import 'package:moodiary/feature/lock/lock_routes.dart';
import 'package:moodiary/feature/setting/setting_routes.dart';
import 'package:moodiary/feature/share/share_routes.dart';
import 'package:moodiary/feature/sync/sync_routes.dart';
import 'package:moodiary/feature/user/user_routes.dart';
import 'package:moodiary/feature/web_view/web_view_routes.dart';

export 'package:moodiary_router/moodiary_router.dart';
export 'package:moodiary_assistant/moodiary_assistant.dart'
    show AssistantSettingRoute;

final moodiaryNavigationKey = GlobalKey<NavigatorState>();

late final GoRouter router;

void buildRouter({String initialLocation = '/'}) {
  router = GoRouter(
    routes: _mobileRoutes(),
    initialLocation: initialLocation,
    navigatorKey: moodiaryNavigationKey,
    observers: [FlutterSmartDialog.observer],
  );
}

@visibleForTesting
List<RouteBase> buildMobileRoutes() => _mobileRoutes();

/// 各 feature 自带路由片段（`xRoutes()`）+ app 侧组合：首页 shell、以及跨 feature 的
/// 助手→选日记页绑定（契约在 moodiary_router / moodiary_assistant，页面归 diary，故 app 绑定）。
List<RouteBase> _mobileRoutes() => [
  GoRoute(
    path: DiaryHomeRoute.path,
    builder: (_, _) => const MobileRootShell(),
  ),
  ...diaryRoutes(),
  ...settingRoutes(),
  ...syncRoutes(),
  ...lockRoutes(),
  ...userRoutes(),
  ...shareRoutes(),
  ...webViewRoutes(),
  ...assistantRoutes(),
  GoRoute(
    path: AssistantDiaryPickerRoute.path,
    builder: (_, _) => const DiarySelectPage(),
  ),
];
