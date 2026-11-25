library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/presentation/toolbar_setting_page.dart';

export 'src/application/edit_controller.dart';
export 'src/data/geo_repository.dart';
export 'src/data/qweather_config.dart';
export 'src/data/weather_repository.dart';
export 'src/editor_providers.dart';
export 'src/media.dart';
export 'src/moodiary_editor.dart';
export 'src/presentation/widget/category_picker_sheet.dart';
export 'src/presentation/widget/editor_body.dart';
export 'src/presentation/widget/moodiary_editor_view.dart';
export 'src/presentation/widget/record_sheet.dart';
export 'src/presentation/widget/tag_picker_sheet.dart';
export 'src/toolbar/editor_command.dart';
export 'src/toolbar/editor_state.dart';

List<RouteBase> editorRoutes() => [
  GoRoute(
    path: EditorToolbarSettingRoute.path,
    builder: (_, _) => const ToolbarSettingPage(),
  ),
];
