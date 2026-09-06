import 'package:moodiary_router/moodiary_router.dart';

import 'presentation/editor_migration_page.dart';

List<RouteBase> editorRoutes() => [
  GoRoute(
    path: EditorMigrationRoute.path,
    builder: (_, _) => const EditorMigrationPage(),
  ),
];
