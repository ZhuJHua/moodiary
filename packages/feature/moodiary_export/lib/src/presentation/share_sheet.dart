import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

import '../data/export_options.dart';
import '../data/export_scope.dart';
import '../data/export_service.dart';
import 'export_page.dart' show shareExported;
import 'pdf_font_page.dart';

Future<void> showDiaryShareSheet(BuildContext context, String diaryId) async {
  final l10n = context.l10n;
  final settings = ExportSettings.decode(
    MoodiaryKVs.exportSettings.get() ?? '',
  );
  final needsFont = settings.pdf.eastAsiaFont.isEmpty;

  final format = await MSheet.picker<ExportFormat>(
    context,
    title: l10n.share.sheetTitle,
    subtitle: l10n.share.sheetSubtitle,
    icon: LucideIcons.share2,
    options: [
      MSheetOption(
        value: .image,
        label: l10n.share.optionImage,
        subtitle: l10n.share.optionImageSubtitle,
        icon: LucideIcons.image,
      ),
      MSheetOption(
        value: .markdown,
        label: 'Markdown',
        subtitle: l10n.share.optionMarkdownSubtitle,
        icon: LucideIcons.fileText,
      ),
      MSheetOption(
        value: .docx,
        label: l10n.export.formatDocx,
        subtitle: l10n.share.optionDocxSubtitle,
        icon: LucideIcons.fileType,
      ),
      MSheetOption(
        value: .pdf,
        label: 'PDF',
        subtitle: needsFont
            ? l10n.share.optionPdfNeedFont
            : l10n.share.optionPdfSubtitle,
        icon: LucideIcons.fileType2,
      ),
    ],
  );
  if (format == null || !context.mounted) return;

  if (format == ExportFormat.image) {
    ShareRoute(diaryId: diaryId).push(context);
    return;
  }
  await _exportSingle(context, format: format, diaryId: diaryId);
}

Future<void> _exportSingle(
  BuildContext context, {
  required ExportFormat format,
  required String diaryId,
}) async {
  final l10n = context.l10n;
  var settings = ExportSettings.decode(MoodiaryKVs.exportSettings.get() ?? '');

  // PDF 必须先有字体：typst 拿不到字体文件会在写文件那一步才失败。
  if (format == ExportFormat.pdf && settings.pdf.eastAsiaFont.isEmpty) {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const PdfFontPage(selected: '')),
    );
    if (picked == null || !context.mounted) return;
    settings = settings.copyWith(
      pdf: settings.pdf.copyWith(eastAsiaFont: picked),
    );
    MoodiaryKVs.exportSettings.set(settings.encode());
  }

  final label = switch (format) {
    ExportFormat.markdown => 'Markdown',
    ExportFormat.docx => l10n.export.formatDocx,
    ExportFormat.pdf => 'PDF',
    ExportFormat.image => l10n.share.optionImage,
  };
  toast.loading(message: l10n.share.generating(format: label));
  try {
    final outcome = await ExportService.run(
      format: format,
      scope: PickedScope({diaryId}),
      settings: settings.copyWith(
        common: settings.common.copyWith(merge: true),
      ),
      untitledLabel: l10n.common.untitled,
      videoLabel: l10n.common.video,
      audioLabel: l10n.common.audio,
    );
    await toast.dismiss();
    await shareExported(outcome.path, l10n);
  } on ExportException catch (e) {
    await toast.dismiss();
    toast.error(
      message: switch (e.error) {
        .emptyScope => l10n.export.scopeEmpty,
        .cancelled => l10n.export.cancelled,
      },
    );
  } catch (e) {
    await toast.dismiss();
    toast.error(message: l10n.export.failed(error: '$e'));
  }
}
