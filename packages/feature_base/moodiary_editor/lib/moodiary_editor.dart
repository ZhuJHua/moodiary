library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/presentation/editor_migration_page.dart';

export 'src/application/edit_controller.dart';
export 'src/data/editor_migration_service.dart';
export 'src/data/geo_repository.dart';
export 'src/data/qweather_config.dart';
export 'src/data/weather_repository.dart';
export 'src/editor_local_server.dart';
export 'src/media.dart';
export 'src/moodiary_editor.dart';
export 'src/presentation/editor_migration_page.dart';
export 'src/presentation/widget/category_picker_sheet.dart';
export 'src/presentation/widget/editor_body.dart';
export 'src/presentation/widget/moodiary_editor_view.dart';
export 'src/presentation/widget/record_sheet.dart';

List<RouteBase> editorRoutes() => [
  GoRoute(
    path: EditorMigrationRoute.path,
    builder: (_, _) => const EditorMigrationPage(),
  ),
];
