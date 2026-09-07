library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/presentation/editor_migration_page.dart';

export 'src/application/edit_controller.dart';
export 'src/data/editor_migration_service.dart' show EditorMigrationService;
export 'src/data/geo_repository.dart'
    show CoordinatesResult, GeoFailure, GeoResult;
export 'src/data/qweather_config.dart' show qweatherCredentials;
export 'src/data/weather_repository.dart' show WeatherResult;
export 'src/editor_local_server.dart' show EditorLocalServer;
export 'src/media.dart'
    show MediaResolver, imageMimeOf, audioMimeOf, videoMimeOf;
export 'src/moodiary_editor.dart'
    show
        MoodiaryEditor,
        MoodiaryEditorController,
        EditorFocusTarget,
        EditorRoles,
        EditorFont,
        DiaryLinkCandidate;
export 'src/presentation/editor_migration_page.dart' show EditorMigrationPage;
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
