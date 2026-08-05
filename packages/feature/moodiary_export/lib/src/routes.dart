import 'package:moodiary_router/moodiary_router.dart';

import 'data/export_options.dart';
import 'presentation/export_page.dart';
import 'presentation/format_export_page.dart';

List<RouteBase> exportRoutes() => [
  GoRoute(path: ExportRoute.path, builder: (_, _) => const ExportPage()),
  GoRoute(
    path: ExportFormatRoute.path,
    builder: (_, state) => FormatExportPage(
      format: ExportFormat.byId(ExportFormatRoute.fromState(state).format),
    ),
  ),
];
