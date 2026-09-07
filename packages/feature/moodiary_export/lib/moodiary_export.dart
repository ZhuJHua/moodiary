library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/presentation/export_page.dart';
import 'src/presentation/format_export_page.dart';
import 'src/presentation/image_export_page.dart';
import 'src/presentation/markdown_import_page.dart';

export 'src/data/export_doc.dart';
export 'src/data/export_options.dart';
export 'src/data/export_scope.dart';
export 'src/data/export_service.dart'
    show ExportService, ExportOutcome, ExportException;
export 'src/data/image_composer.dart'
    show ImageComposer, ImageComposeResult, imageBands;
export 'src/data/import/import_media_stage.dart'
    show
        AppImportMediaStore,
        ImportMediaKind,
        ImportMediaStore,
        ImportMediaStage;
export 'src/data/import/import_source.dart';
export 'src/data/import/markdown_front_matter.dart';
export 'src/data/import/markdown_importer.dart';
export 'src/data/markdown_writer.dart';
export 'src/data/tiptap_to_ir.dart';
export 'src/presentation/share_sheet.dart' show showDiaryShareSheet;

List<RouteBase> exportRoutes() => [
  GoRoute(path: ExportRoute.path, builder: (_, _) => const ExportPage()),
  // 路径不能改：app_lock_observer 里按字面量放行它。
  GoRoute(
    path: ShareRoute.path,
    builder: (_, state) => ImageExportPage.fromRoute(state),
  ),
  GoRoute(
    path: ImportMarkdownRoute.path,
    builder: (_, _) => const MarkdownImportPage(),
  ),
  GoRoute(
    path: ExportFormatRoute.path,
    builder: (_, state) => FormatExportPage.fromRoute(state),
  ),
];
