import 'package:moodiary_router/moodiary_router.dart';

import 'presentation/editor_migration_page.dart';

/// 编辑器包自带路由片段：旧编辑器 → tiptap 的可视化迁移工具页。
List<RouteBase> editorRoutes() => [
  MoodiaryGoRoute(
    path: EditorMigrationRoute.path,
    builder: (_, _) => const EditorMigrationPage(),
  ),
];
