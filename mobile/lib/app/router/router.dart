import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary/feature/assistant/presentation/assistant_page.dart';
import 'package:moodiary/feature/diary/presentation/analyse/analyse_page.dart';
import 'package:moodiary/feature/diary/presentation/category/category_manager_page.dart';
import 'package:moodiary/feature/diary/presentation/detail/diary_page.dart'
    show DiaryPage;
import 'package:moodiary/feature/diary/presentation/manager/diary_manager_page.dart';
import 'package:moodiary/feature/diary/presentation/map/map_page.dart';
import 'package:moodiary/feature/diary/presentation/recycle/recycle_page.dart';
import 'package:moodiary/feature/diary/presentation/search/search_page.dart';
import 'package:moodiary/feature/diary/presentation/diary_select_page.dart';
import 'package:moodiary/app/shell/root_shell.dart' show MobileRootShell;
import 'package:moodiary/feature/lock/presentation/lock_page.dart';
import 'package:moodiary/feature/lock/presentation/start_page.dart';
import 'package:moodiary/feature/setting/presentation/about_page.dart';
import 'package:moodiary/feature/setting/presentation/agreement_page.dart';
import 'package:moodiary/feature/setting/presentation/assistant_provider_edit_page.dart';
import 'package:moodiary/feature/setting/presentation/assistant_provider_list_page.dart';
import 'package:moodiary/feature/setting/presentation/assistant_provider_picker_page.dart';
import 'package:moodiary/feature/setting/presentation/assistant_setting_page.dart';
import 'package:moodiary/feature/sync/presentation/backup_sync_page.dart';
import 'package:moodiary/feature/setting/presentation/diary_setting_page.dart';
import 'package:moodiary/feature/setting/presentation/editor_migration_page.dart';
import 'package:moodiary/feature/setting/presentation/font_page.dart';
import 'package:moodiary/feature/setting/presentation/privacy_page.dart';
import 'package:moodiary/feature/setting/presentation/services_page.dart';
import 'package:moodiary/feature/setting/presentation/sponsor_page.dart';
import 'package:moodiary/feature/share/presentation/share_page.dart';
import 'package:moodiary/feature/sync/presentation/sync_log_page.dart';
import 'package:moodiary/feature/user/presentation/login_page.dart';
import 'package:moodiary/feature/user/presentation/user_page.dart';
import 'package:moodiary/feature/web_view/presentation/web_view_page.dart';
import 'package:moodiary/app/router/route_base.dart';

export 'package:moodiary/app/router/route_base.dart'
    show MoodiaryRouteBase, MoodiaryRouteNav;

// Root navigator key（移动端无内层 shell：首页与详情路由都是顶层兄弟，同落 root navigator）。
final moodiaryNavigationKey = GlobalKey<NavigatorState>();

late final GoRouter router;

/// 移动端路由树：`/` 是 4-Tab 首页 shell，详情路由是它的顶层兄弟（全屏 push 盖过底栏）。
void buildRouter({String initialLocation = '/'}) {
  router = GoRouter(
    routes: _mobileRoutes(),
    initialLocation: initialLocation,
    navigatorKey: moodiaryNavigationKey,
    observers: [FlutterSmartDialog.observer],
  );
}

/// 测试用：取移动端路由树。
@visibleForTesting
List<RouteBase> buildMobileRoutes() => _mobileRoutes();

/// 构造一个 leaf 路由：走默认页面，保留系统 push 动画。
GoRoute _leafRoute(
  String path,
  Widget Function(BuildContext, GoRouterState) builder,
) => GoRoute(path: path, builder: builder);

List<RouteBase> _diaryLeafRoutes() => [
  _leafRoute(DiaryRoute.path, (context, state) => DiaryRoute.fromState(state).build()),
  _leafRoute(ShareRoute.path, (context, state) => ShareRoute.fromState(state).build()),
];

/// Setting 分支的子页路由。「数据管理」类页面（回收站 / 分类管理 / 地图 /
/// 数据分析）路径虽不在 `/setting/*` 下，但都从设置页进入，故一并归到 Setting 分支。
List<RouteBase> _settingLeafRoutes() => [
  _leafRoute(RecycleRoute.path, (_, _) => const RecyclePage()),
  _leafRoute(BackupSyncRoute.path, (_, _) => const BackupSyncPage()),
  _leafRoute(CategoryManagerRoute.path, (_, _) => const CategoryManagerPage()),
  _leafRoute(MapRoute.path, (_, _) => const MapPage()),
  _leafRoute(DiaryManagerRoute.path, (_, _) => const DiaryManagerPage()),
  _leafRoute(AnalyseRoute.path, (_, _) => const AnalysePage()),
  _leafRoute(DiarySettingRoute.path, (_, _) => const DiarySettingPage()),
  _leafRoute(EditorMigrationRoute.path, (_, _) => const EditorMigrationPage()),
  _leafRoute(FontRoute.path, (_, _) => const FontPage()),
  _leafRoute(ServicesRoute.path, (_, _) => const ServicesPage()),
  _leafRoute(AboutRoute.path, (_, _) => const AboutPage()),
  _leafRoute(PrivacyRoute.path, (_, _) => const PrivacyPage()),
  _leafRoute(AgreementRoute.path, (_, _) => const AgreementPage()),
  _leafRoute(UserRoute.path, (_, _) => const UserPage()),
  _leafRoute(SponsorRoute.path, (_, _) => const SponsorPage()),
];

/// Shell 外的全屏路由（顶层兄弟，全屏 push 盖过 shell）。
List<RouteBase> _globalRoutes() => [
  GoRoute(
    path: LockRoute.path,
    builder: (context, state) => LockRoute.fromState(state).build(),
  ),
  GoRoute(path: StartRoute.path, builder: (_, _) => const StartPage()),
  GoRoute(path: LoginRoute.path, builder: (_, _) => const LoginPage()),
  GoRoute(
    path: SyncLogRoute.path,
    builder: (_, _) => const SyncLogPage(),
  ),
  GoRoute(
    path: WebViewRoute.path,
    builder: (context, state) => WebViewRoute.fromState(state).build(),
  ),
  GoRoute(
    path: DiarySearchRoute.path,
    builder: (_, _) => const DiarySearchPage(),
  ),
  // AI 助手配置流从助手 Tab 与第三方服务页两处进入，故作 shell 外全屏路由落 root
  // navigator（全屏盖过 shell，底栏隐藏）。
  GoRoute(
    path: AssistantSettingRoute.path,
    builder: (_, _) => const AssistantSettingPage(),
  ),
  GoRoute(
    path: AssistantProvidersRoute.path,
    builder: (_, _) => const AssistantProviderListPage(),
  ),
  GoRoute(
    path: AssistantProviderPickerRoute.path,
    builder: (_, _) => const AssistantProviderPickerPage(),
  ),
  GoRoute(
    path: AssistantProviderEditRoute.path,
    builder: (context, state) => AssistantProviderEditPage(
      id: state.uri.queryParameters['id'],
      presetId: state.uri.queryParameters['preset'],
    ),
  ),
  // 助手会话详情：移动端从会话列表 / 玻璃底栏「新建对话」push，全屏盖 shell（底栏隐藏）。
  GoRoute(
    path: AssistantConversationRoute.path,
    builder: (context, state) =>
        AssistantConversationRoute.fromState(state).build(),
  ),
  // 助手「发送日记」选择页：单页选择器，pop 时回传选中的 Diary。
  GoRoute(
    path: AssistantDiaryPickerRoute.path,
    builder: (_, _) => const DiarySelectPage(),
  ),
];

/// 移动端：单 `/` 路由渲染 4-Tab 首页（[MobileRootShell] 内 IndexedStack，各 Tab
/// 本地 index 驱动、保活），详情路由全部作顶层兄弟（全屏盖过底栏）。
List<RouteBase> _mobileRoutes() => [
  GoRoute(path: DiaryHomeRoute.path, builder: (_, _) => const MobileRootShell()),
  ..._diaryLeafRoutes(),
  ..._settingLeafRoutes(),
  ..._globalRoutes(),
];

// DiaryType 的 URL 编码：复刻原 go_router_builder 的约定（markdown / rich-text），
// 与 DiaryType.value（'richText'）不同，务必保持以维持深链 / 参数契约不变。
const Map<DiaryType, String> _diaryTypeToQuery = {
  DiaryType.markdown: 'markdown',
  DiaryType.richText: 'rich-text',
  DiaryType.tiptap: 'tiptap',
};

/// URL `type` query → [DiaryType]，无法识别时返回 null（与深链编码契约一致）。
DiaryType? diaryTypeFromQueryOrNull(String? value) {
  if (value == null) return null;
  for (final entry in _diaryTypeToQuery.entries) {
    if (entry.value == value) return entry.key;
  }
  return null;
}

class DiaryRoute extends MoodiaryRouteBase {
  static const String path = '/diary/:diaryId';

  final DiaryType type;
  final String diaryId;

  /// 进入即编辑（新建 / 从草稿继续）。默认进入阅读态。
  final bool edit;

  const DiaryRoute({
    required this.type,
    required this.diaryId,
    this.edit = false,
  });

  @override
  String get location => buildLocation('/diary/${Uri.encodeComponent(diaryId)}', {
    'type': _diaryTypeToQuery[type],
    if (edit) 'edit': 'true',
  });

  static DiaryRoute fromState(GoRouterState state) => DiaryRoute(
    diaryId: state.pathParameters['diaryId']!,
    // 缺失 / 无法识别的 type 兜底为 tiptap（当前默认类型），避免深链或新建时空指针。
    type:
        diaryTypeFromQueryOrNull(state.uri.queryParameters['type']) ??
        DiaryType.tiptap,
    edit: state.uri.queryParameters['edit'] == 'true',
  );

  Widget build() =>
      DiaryPage(diaryId: diaryId, initialType: type, startInEdit: edit);
}

class ShareRoute extends MoodiaryRouteBase {
  static const String path = '/share';

  final String? diaryId;

  const ShareRoute({this.diaryId});

  @override
  String get location => buildLocation('/share', {'diary-id': diaryId});

  static ShareRoute fromState(GoRouterState state) =>
      ShareRoute(diaryId: state.uri.queryParameters['diary-id']);

  Widget build() => SharePage(diaryId: diaryId);
}

class WebViewRoute extends MoodiaryRouteBase {
  static const String path = '/web_view';

  final String url;
  final String title;

  const WebViewRoute({required this.url, this.title = ''});

  @override
  String get location => buildLocation('/web_view', {
    'url': url,
    'title': title.isEmpty ? null : title,
  });

  static WebViewRoute fromState(GoRouterState state) => WebViewRoute(
    url: state.uri.queryParameters['url']!,
    title: state.uri.queryParameters['title'] ?? '',
  );

  Widget build() => WebViewPage(url: url, title: title);
}

class LockRoute extends MoodiaryRouteBase {
  static const String path = '/lock';

  final String? lockType;

  const LockRoute({this.lockType});

  @override
  String get location => buildLocation('/lock', {'lock-type': lockType});

  static LockRoute fromState(GoRouterState state) =>
      LockRoute(lockType: state.uri.queryParameters['lock-type']);

  Widget build() => LockPage(lockType: lockType);
}

class DiaryHomeRoute extends MoodiaryRouteBase {
  static const String path = '/';
  const DiaryHomeRoute();
  @override
  String get location => path;
}

class RecycleRoute extends MoodiaryRouteBase {
  static const String path = '/recycle';
  const RecycleRoute();
  @override
  String get location => path;
}

class DiarySearchRoute extends MoodiaryRouteBase {
  static const String path = '/search';
  const DiarySearchRoute();
  @override
  String get location => path;
}

class DiaryManagerRoute extends MoodiaryRouteBase {
  static const String path = '/diary_manager';
  const DiaryManagerRoute();
  @override
  String get location => path;
}

class CategoryManagerRoute extends MoodiaryRouteBase {
  static const String path = '/category_manager';
  const CategoryManagerRoute();
  @override
  String get location => path;
}

class MapRoute extends MoodiaryRouteBase {
  static const String path = '/map';
  const MapRoute();
  @override
  String get location => path;
}

class AnalyseRoute extends MoodiaryRouteBase {
  static const String path = '/analyse';
  const AnalyseRoute();
  @override
  String get location => path;
}

class FontRoute extends MoodiaryRouteBase {
  static const String path = '/setting/font';
  const FontRoute();
  @override
  String get location => path;
}

class ServicesRoute extends MoodiaryRouteBase {
  static const String path = '/setting/services';
  const ServicesRoute();
  @override
  String get location => path;
}

class PrivacyRoute extends MoodiaryRouteBase {
  static const String path = '/setting/privacy';
  const PrivacyRoute();
  @override
  String get location => path;
}

class AgreementRoute extends MoodiaryRouteBase {
  static const String path = '/setting/agreement';
  const AgreementRoute();
  @override
  String get location => path;
}

class UserRoute extends MoodiaryRouteBase {
  static const String path = '/setting/user';
  const UserRoute();
  @override
  String get location => path;
}

class AboutRoute extends MoodiaryRouteBase {
  static const String path = '/setting/about';
  const AboutRoute();
  @override
  String get location => path;
}

class DiarySettingRoute extends MoodiaryRouteBase {
  static const String path = '/setting/diary_setting';
  const DiarySettingRoute();
  @override
  String get location => path;
}

class EditorMigrationRoute extends MoodiaryRouteBase {
  static const String path = '/setting/editor_migration';
  const EditorMigrationRoute();
  @override
  String get location => path;
}

class BackupSyncRoute extends MoodiaryRouteBase {
  static const String path = '/setting/backup_sync';
  const BackupSyncRoute();
  @override
  String get location => path;
}

class AssistantSettingRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant_setting';
  const AssistantSettingRoute();
  @override
  String get location => path;
}

class AssistantConversationRoute extends MoodiaryRouteBase {
  static const String path = '/assistant/conversation';

  /// 要打开的会话 id；null 表示新建对话（首次发送时落库）。
  final String? sessionId;

  const AssistantConversationRoute({this.sessionId});

  @override
  String get location => buildLocation(path, {'session-id': sessionId});

  static AssistantConversationRoute fromState(GoRouterState state) =>
      AssistantConversationRoute(
        sessionId: state.uri.queryParameters['session-id'],
      );

  Widget build() => AssistantPage(initialSessionId: sessionId);
}

class AssistantDiaryPickerRoute extends MoodiaryRouteBase {
  static const String path = '/assistant/diary_picker';
  const AssistantDiaryPickerRoute();
  @override
  String get location => path;
}

class AssistantProvidersRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant/providers';
  const AssistantProvidersRoute();
  @override
  String get location => path;
}

class AssistantProviderPickerRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant/provider_picker';
  const AssistantProviderPickerRoute();
  @override
  String get location => path;
}

class AssistantProviderEditRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant/provider_edit';

  /// 编辑已有供应商时传 [id]；从预设新建时传 [presetId]。
  final String? id;
  final String? presetId;
  const AssistantProviderEditRoute({this.id, this.presetId});
  @override
  String get location => buildLocation(path, {'id': id, 'preset': presetId});
}

class SponsorRoute extends MoodiaryRouteBase {
  static const String path = '/setting/sponsor';
  const SponsorRoute();
  @override
  String get location => path;
}

class StartRoute extends MoodiaryRouteBase {
  static const String path = '/start';
  const StartRoute();
  @override
  String get location => path;
}

class LoginRoute extends MoodiaryRouteBase {
  static const String path = '/login';
  const LoginRoute();
  @override
  String get location => path;
}

class SyncLogRoute extends MoodiaryRouteBase {
  static const String path = '/sync_log';
  const SyncLogRoute();
  @override
  String get location => path;
}
