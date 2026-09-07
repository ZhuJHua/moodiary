library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

export 'package:go_router/go_router.dart';

export 'src/route_observer.dart';

abstract class MoodiaryRouteBase {
  final String location;

  const MoodiaryRouteBase(this.location);

  Map<String, dynamic>? get params => null;
}

extension MoodiaryRouteNav on MoodiaryRouteBase {
  Future<T?> push<T extends Object?>(BuildContext context) =>
      context.push<T>(location, extra: params);

  void go(BuildContext context) => context.go(location, extra: params);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: params);

  void replace(BuildContext context) =>
      context.replace(location, extra: params);
}

extension MoodiaryGoRouterNav on GoRouter {
  Future<T?> pushRoute<T extends Object?>(MoodiaryRouteBase route) =>
      push<T>(route.location, extra: route.params);
}

extension MoodiaryRouteState on GoRouterState {
  Map<String, dynamic> get params => switch (extra) {
    final Map<String, dynamic> map => map,
    _ => const {},
  };
}

class DiaryHomeRoute extends MoodiaryRouteBase {
  static const String path = '/';

  const DiaryHomeRoute() : super(path);
}

class DiaryRoute extends MoodiaryRouteBase {
  static const String path = '/diary';

  final String diaryId;
  final bool edit;

  const DiaryRoute({required this.diaryId, this.edit = false}) : super(path);

  @override
  Map<String, dynamic> get params => {'diary_id': diaryId, 'edit': edit};
}

class NewDiaryRoute extends MoodiaryRouteBase {
  static const String path = '/diary-new';

  final String? categoryId;

  const NewDiaryRoute({this.categoryId}) : super(path);

  @override
  Map<String, dynamic> get params => {'category_id': categoryId, 'edit': true};
}

class ShareRoute extends MoodiaryRouteBase {
  static const String path = '/share';

  final String? diaryId;

  const ShareRoute({this.diaryId}) : super(path);

  @override
  Map<String, dynamic> get params => {'diary_id': diaryId};
}

class LockRoute extends MoodiaryRouteBase {
  static const String path = '/lock';

  final String? lockType;

  const LockRoute({this.lockType}) : super(path);

  @override
  Map<String, dynamic> get params => {'lock_type': lockType};
}

class RecycleRoute extends MoodiaryRouteBase {
  static const String path = '/recycle';

  const RecycleRoute() : super(path);
}

class DiarySearchRoute extends MoodiaryRouteBase {
  static const String path = '/search';

  const DiarySearchRoute() : super(path);
}

class DiaryManagerRoute extends MoodiaryRouteBase {
  static const String path = '/diary_manager';

  const DiaryManagerRoute() : super(path);
}

class CategoryManagerRoute extends MoodiaryRouteBase {
  static const String path = '/category_manager';

  const CategoryManagerRoute() : super(path);
}

class PlaceManagerRoute extends MoodiaryRouteBase {
  static const String path = '/place_manager';

  const PlaceManagerRoute() : super(path);
}

class MapRoute extends MoodiaryRouteBase {
  static const String path = '/map';

  const MapRoute() : super(path);
}

class MediaRoute extends MoodiaryRouteBase {
  static const String path = '/media';

  const MediaRoute() : super(path);
}

class CalendarRoute extends MoodiaryRouteBase {
  static const String path = '/calendar';

  const CalendarRoute() : super(path);
}

class DiaryGraphRoute extends MoodiaryRouteBase {
  static const String path = '/graph';

  final String? diaryId;

  const DiaryGraphRoute({this.diaryId}) : super(path);

  @override
  Map<String, dynamic> get params => {'diary_id': diaryId};
}

class SettingRoute extends MoodiaryRouteBase {
  static const String path = '/setting';

  const SettingRoute() : super(path);
}

class EditorMigrationRoute extends MoodiaryRouteBase {
  static const String path = '/migration';

  const EditorMigrationRoute() : super(path);
}

class BackupSyncRoute extends MoodiaryRouteBase {
  static const String path = '/setting/backup_sync';

  const BackupSyncRoute() : super(path);
}

class ExportRoute extends MoodiaryRouteBase {
  static const String path = '/setting/export';

  const ExportRoute() : super(path);
}

class ExportFormatRoute extends MoodiaryRouteBase {
  static const String path = '/setting/export/format';

  final String format;

  const ExportFormatRoute({required this.format}) : super(path);

  @override
  Map<String, dynamic> get params => {'format': format};
}

class ImportMarkdownRoute extends MoodiaryRouteBase {
  static const String path = '/setting/export/import-markdown';

  const ImportMarkdownRoute() : super(path);
}

class SyncLogRoute extends MoodiaryRouteBase {
  static const String path = '/sync_log';

  const SyncLogRoute() : super(path);
}

class LanSendRoute extends MoodiaryRouteBase {
  static const String path = '/lan/send';

  const LanSendRoute() : super(path);
}

class LanReceiveRoute extends MoodiaryRouteBase {
  static const String path = '/lan/receive';

  const LanReceiveRoute() : super(path);
}

class AssistantSettingRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant_setting';

  const AssistantSettingRoute() : super(path);
}

class AssistantPresetsRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant/presets';

  const AssistantPresetsRoute() : super(path);
}

class AssistantPresetEditRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant/preset_edit';

  final String? id;
  final String? fromId;

  const AssistantPresetEditRoute({this.id, this.fromId}) : super(path);

  @override
  Map<String, dynamic> get params => {'id': id, 'from_id': fromId};
}

class AssistantConversationRoute extends MoodiaryRouteBase {
  static const String path = '/assistant/conversation';

  final String? sessionId;

  const AssistantConversationRoute({this.sessionId}) : super(path);

  @override
  Map<String, dynamic> get params => {'session_id': sessionId};
}

class AssistantDiaryPickerRoute extends MoodiaryRouteBase {
  static const String path = '/assistant/diary_picker';

  const AssistantDiaryPickerRoute() : super(path);
}

class AssistantProvidersRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant/providers';

  const AssistantProvidersRoute() : super(path);
}

class AssistantProviderPickerRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant/provider_picker';

  const AssistantProviderPickerRoute() : super(path);
}

class AssistantProviderEditRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant/provider_edit';

  final String? id;
  final String? presetId;

  const AssistantProviderEditRoute({this.id, this.presetId}) : super(path);

  @override
  Map<String, dynamic> get params => {'id': id, 'preset_id': presetId};
}
