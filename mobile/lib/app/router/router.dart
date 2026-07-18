import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart' show FlutterSmartDialog;
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart';

import 'package:moodiary/app/shell/root_shell.dart' show MobileRootShell;
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_editor/moodiary_editor.dart' show editorRoutes;
import 'package:moodiary_lock/moodiary_lock.dart';
import 'package:moodiary/app/settings/setting_routes.dart';
import 'package:moodiary_share/moodiary_share.dart';
import 'package:moodiary_sync/moodiary_sync.dart';

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
    observers: [FlutterSmartDialog.observer, moodiaryRouteObserver],
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
  ...shareRoutes(),
  ...editorRoutes(),
  ...assistantRoutes(),
  GoRoute(
    path: AssistantDiaryPickerRoute.path,
    builder: (_, _) => const DiarySelectPage(),
  ),
];
