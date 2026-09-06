import 'package:go_router/go_router.dart';

import 'route_base.dart';

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

class PlaceManagerRoute extends MoodiaryRouteBase {
  static const String path = '/place_manager';
  const PlaceManagerRoute();
  @override
  String get location => path;
}

class MapRoute extends MoodiaryRouteBase {
  static const String path = '/map';
  const MapRoute();
  @override
  String get location => path;
}

class MediaRoute extends MoodiaryRouteBase {
  static const String path = '/media';
  const MediaRoute();
  @override
  String get location => path;
}

class CalendarRoute extends MoodiaryRouteBase {
  static const String path = '/calendar';
  const CalendarRoute();
  @override
  String get location => path;
}

class DiaryGraphRoute extends MoodiaryRouteBase {
  static const String path = '/graph';

  final String? diaryId;

  const DiaryGraphRoute({this.diaryId});

  @override
  String get location => buildLocation(path, {'diary-id': diaryId});

  static DiaryGraphRoute fromState(GoRouterState state) =>
      DiaryGraphRoute(diaryId: state.uri.queryParameters['diary-id']);
}

class SettingRoute extends MoodiaryRouteBase {
  static const String path = '/setting';
  const SettingRoute();
  @override
  String get location => path;
}

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

class ImportMarkdownRoute extends MoodiaryRouteBase {
  static const String path = '/setting/export/import-markdown';
  const ImportMarkdownRoute();
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
