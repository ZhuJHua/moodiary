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

  const DiaryRoute({
    required this.type,
    required this.diaryId,
    this.edit = false,
  });

  @override
  String get location => buildLocation(
    '/diary/${Uri.encodeComponent(diaryId)}',
    {'type': type, if (edit) 'edit': 'true'},
  );

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
  String get location =>
      buildLocation('/diary-new', {'type': type, 'category-id': categoryId});

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

/// 媒体库。2.8.0 前它只是底栏的一格、连路由都没有；降级进「我的 · 回顾」后才需要
/// 一条路径。
class MediaRoute extends MoodiaryRouteBase {
  static const String path = '/media';
  const MediaRoute();
  @override
  String get location => path;
}

/// 月历回顾。与地图、知识图谱同级，都是「同一批日记的另一个投影」。
class CalendarRoute extends MoodiaryRouteBase {
  static const String path = '/calendar';
  const CalendarRoute();
  @override
  String get location => path;
}

/// 知识图谱。[diaryId] 为空 = 总图谱；给定则打开以该篇为中心的局部关系图。
class DiaryGraphRoute extends MoodiaryRouteBase {
  static const String path = '/graph';

  final String? diaryId;

  const DiaryGraphRoute({this.diaryId});

  @override
  String get location => buildLocation(path, {'diary-id': diaryId});

  static DiaryGraphRoute fromState(GoRouterState state) =>
      DiaryGraphRoute(diaryId: state.uri.queryParameters['diary-id']);
}

class FontRoute extends MoodiaryRouteBase {
  static const String path = '/setting/font';
  const FontRoute();
  @override
  String get location => path;
}

/// 自定义强调色取色页。灰度 / 壁纸两档在弹窗里一步选完，只有自定义才进这一层。
class AccentRoute extends MoodiaryRouteBase {
  static const String path = '/setting/accent';
  const AccentRoute();
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

/// 设置列表页。底栏只剩三个 tab 之后设置不再常驻，入口在分类抽屉底部。
class SettingRoute extends MoodiaryRouteBase {
  static const String path = '/setting';
  const SettingRoute();
  @override
  String get location => path;
}

class DiarySettingRoute extends MoodiaryRouteBase {
  static const String path = '/setting/diary_setting';
  const DiarySettingRoute();
  @override
  String get location => path;
}

/// 强制迁移页（启动闸门）。不再挂在设置下：存在旧格式日记时由路由 redirect 全局兜底进入。
class EditorMigrationRoute extends MoodiaryRouteBase {
  static const String path = '/migration';
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

class ExportRoute extends MoodiaryRouteBase {
  static const String path = '/setting/export';
  const ExportRoute();
  @override
  String get location => path;
}

/// 单个格式的导出配置页。[format] 为 `markdown` / `docx` / `pdf`。
class ExportFormatRoute extends MoodiaryRouteBase {
  static const String path = '/setting/export/format';

  final String format;

  const ExportFormatRoute({required this.format});

  @override
  String get location =>
      buildLocation('/setting/export/format', {'format': format});

  static ExportFormatRoute fromState(GoRouterState state) => ExportFormatRoute(
    format: state.uri.queryParameters['format'] ?? 'markdown',
  );
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
