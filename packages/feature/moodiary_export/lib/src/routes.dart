import 'package:moodiary_router/moodiary_router.dart';

import 'presentation/export_page.dart';
import 'presentation/format_export_page.dart';
import 'presentation/image_export_page.dart';
import 'presentation/markdown_import_page.dart';

List<RouteBase> exportRoutes() => [
  GoRoute(path: ExportRoute.path, builder: (_, _) => const ExportPage()),
  // 路径不能改：app_lock_observer 里按字面量放行它。
  GoRoute(
    path: ShareRoute.path,
    builder: (_, state) =>
        ImageExportPage(diaryId: ShareRoute.fromState(state).diaryId),
  ),
  GoRoute(
    path: ImportMarkdownRoute.path,
    builder: (_, _) => const MarkdownImportPage(),
  ),
  GoRoute(
    path: ExportFormatRoute.path,
    builder: (_, state) => FormatExportPage(
      format: .byId(ExportFormatRoute.fromState(state).format),
    ),
  ),
];
