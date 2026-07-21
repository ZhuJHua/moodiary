import 'package:go_router/go_router.dart';

import 'route_base.dart';

/// 移动端应用的路由契约（location / path / 参数解析）。仅收发字符串，不依赖领域枚举，
/// 故本包保持 foundation 纯叶子；页面构建（builder）留在各 feature 的 `xRoutes()` 里。
///
/// `type` 字段是 DiaryType 的路由查询编码（见 moodiary_models 的 `diaryTypeFromRouteQuery`）。

class DiaryHomeRoute extends MoodiaryRouteBase {
  static const String path = '/';
  const DiaryHomeRoute();
  @override
  String get location => path;
}

class DiaryRoute extends MoodiaryRouteBase {
  static const String path = '/diary/:diaryId';

  final String type;
  final String diaryId;
  final bool edit;

  const DiaryRoute({required this.type, required this.diaryId, this.edit = false});

  @override
  String get location => buildLocation('/diary/${Uri.encodeComponent(diaryId)}', {
    'type': type,
    if (edit) 'edit': 'true',
  });

  static DiaryRoute fromState(GoRouterState state) => DiaryRoute(
    diaryId: state.pathParameters['diaryId']!,
    type: state.uri.queryParameters['type'] ?? 'tiptap',
    edit: state.uri.queryParameters['edit'] == 'true',
  );
}

class NewDiaryRoute extends MoodiaryRouteBase {
  static const String path = '/diary-new';

  final String type;

  final String? categoryId;

  const NewDiaryRoute({required this.type, this.categoryId});

  @override
  String get location => buildLocation('/diary-new', {
    'type': type,
    'category-id': categoryId,
  });

  static NewDiaryRoute fromState(GoRouterState state) => NewDiaryRoute(
    type: state.uri.queryParameters['type'] ?? 'tiptap',
    categoryId: state.uri.queryParameters['category-id'],
  );
}

class ShareRoute extends MoodiaryRouteBase {
  static const String path = '/share';

  final String? diaryId;

  const ShareRoute({this.diaryId});

  @override
  String get location => buildLocation('/share', {'diary-id': diaryId});

  static ShareRoute fromState(GoRouterState state) =>
      ShareRoute(diaryId: state.uri.queryParameters['diary-id']);
}

class LockRoute extends MoodiaryRouteBase {
  static const String path = '/lock';

  final String? lockType;

  const LockRoute({this.lockType});

  @override
  String get location => buildLocation('/lock', {'lock-type': lockType});

  static LockRoute fromState(GoRouterState state) =>
      LockRoute(lockType: state.uri.queryParameters['lock-type']);
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

class DiaryGraphRoute extends MoodiaryRouteBase {
  static const String path = '/graph';
  const DiaryGraphRoute();
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

class SyncLogRoute extends MoodiaryRouteBase {
  static const String path = '/sync_log';
  const SyncLogRoute();
  @override
  String get location => path;
}

class LanSendRoute extends MoodiaryRouteBase {
  static const String path = '/lan/send';
  const LanSendRoute();
  @override
  String get location => path;
}

class LanReceiveRoute extends MoodiaryRouteBase {
  static const String path = '/lan/receive';
  const LanReceiveRoute();
  @override
  String get location => path;
}
