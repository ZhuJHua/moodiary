import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart';
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
import 'package:moodiary_router/moodiary_router.dart';

export 'package:moodiary_router/moodiary_router.dart'
    show MoodiaryRouteBase, MoodiaryRouteNav;

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

GoRoute _leafRoute(
  String path,
  Widget Function(BuildContext, GoRouterState) builder,
) => GoRoute(path: path, builder: builder);

List<RouteBase> _diaryLeafRoutes() => [
  _leafRoute(
    NewDiaryRoute.path,
    (context, state) => NewDiaryRoute.fromState(state).build(),
  ),
  _leafRoute(
    DiaryRoute.path,
    (context, state) => DiaryRoute.fromState(state).build(),
  ),
  _leafRoute(
    ShareRoute.path,
    (context, state) => ShareRoute.fromState(state).build(),
  ),
];

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

List<RouteBase> _globalRoutes() => [
  GoRoute(
    path: LockRoute.path,
    builder: (context, state) => LockRoute.fromState(state).build(),
  ),
  GoRoute(path: StartRoute.path, builder: (_, _) => const StartPage()),
  GoRoute(path: LoginRoute.path, builder: (_, _) => const LoginPage()),
  GoRoute(path: SyncLogRoute.path, builder: (_, _) => const SyncLogPage()),
  GoRoute(
    path: WebViewRoute.path,
    builder: (context, state) => WebViewRoute.fromState(state).build(),
  ),
  GoRoute(
    path: DiarySearchRoute.path,
    builder: (_, _) => const DiarySearchPage(),
  ),
  ...assistantRoutes(),
  GoRoute(
    path: AssistantDiaryPickerRoute.path,
    builder: (_, _) => const DiarySelectPage(),
  ),
];

List<RouteBase> _mobileRoutes() => [
  GoRoute(
    path: DiaryHomeRoute.path,
    builder: (_, _) => const MobileRootShell(),
  ),
  ..._diaryLeafRoutes(),
  ..._settingLeafRoutes(),
  ..._globalRoutes(),
];

const Map<DiaryType, String> _diaryTypeToQuery = {
  DiaryType.markdown: 'markdown',
  DiaryType.richText: 'rich-text',
  DiaryType.tiptap: 'tiptap',
};

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

  final bool edit;

  const DiaryRoute({
    required this.type,
    required this.diaryId,
    this.edit = false,
  });

  @override
  String get location => buildLocation(
    '/diary/${Uri.encodeComponent(diaryId)}',
    {'type': _diaryTypeToQuery[type], if (edit) 'edit': 'true'},
  );

  static DiaryRoute fromState(GoRouterState state) => DiaryRoute(
    diaryId: state.pathParameters['diaryId']!,
    type:
        diaryTypeFromQueryOrNull(state.uri.queryParameters['type']) ??
        DiaryType.tiptap,
    edit: state.uri.queryParameters['edit'] == 'true',
  );

  Widget build() =>
      DiaryPage(diaryId: diaryId, initialType: type, startInEdit: edit);
}

class NewDiaryRoute extends MoodiaryRouteBase {
  static const String path = '/diary-new';

  final DiaryType type;

  const NewDiaryRoute({required this.type});

  @override
  String get location =>
      buildLocation('/diary-new', {'type': _diaryTypeToQuery[type]});

  static NewDiaryRoute fromState(GoRouterState state) => NewDiaryRoute(
    type:
        diaryTypeFromQueryOrNull(state.uri.queryParameters['type']) ??
        DiaryType.tiptap,
  );

  Widget build() => DiaryPage(initialType: type, startInEdit: true);
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
