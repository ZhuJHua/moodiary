import 'dart:io';

import 'package:gap/gap.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';
import 'package:share_plus/share_plus.dart';

import '../data/export_options.dart';

/// 「导入与导出」主页：导出按格式摊平成卡片，导入按来源摊平。
///
/// 本地备份 zip 的进出原本在同步页，已经搬到这里 —— 同步页只管远端，本地文件进出入口唯一。
/// 归档实现仍在 moodiary_sync，经 core 的 [IBackupArchive] 端口拿到（feature 之间不互相 import）。
class ExportPage extends StatelessWidget {
  const ExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.export.pageTitle)),
      body: Padding(
        padding: const .symmetric(horizontal: 8.0),
        child: CustomScrollView(
          slivers: [
            const _ExportSection(),
            const _ImportSection(),
            SliverGap(context.safeBottom),
          ],
        ),
      ),
    );
  }
}

class _ExportSection extends StatelessWidget {
  const _ExportSection();

  @override
  Widget build(BuildContext context) {
    return MSliverSettingGroup(
      title: context.l10n.export.sectionExport,
      children: [
        SettingListTile(
          title: 'Markdown',
          leading: const FileTypeIcon('MD'),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => _open(context, .markdown),
        ),
        SettingListTile(
          title: context.l10n.export.formatDocx,
          leading: const FileTypeIcon('DOCX'),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => _open(context, .docx),
        ),
        SettingListTile(
          title: 'PDF',
          leading: const FileTypeIcon('PDF'),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => _open(context, .pdf),
        ),
      ],
    );
  }

  void _open(BuildContext context, ExportFormat format) =>
      ExportFormatRoute(format: format.id).push(context);
}

class _ImportSection extends StatelessWidget {
  const _ImportSection();

  Future<void> _restoreBackup(BuildContext context) async {
    // 在第一个 await 之前取好：之后 context 可能已经不 mounted。
    final l10n = context.l10n;
    final file = await IFilePicker.get().pickFile(allowedExtensions: ['zip']);
    if (file == null || !context.mounted) return;

    final confirmed = await MAlert.confirm(
      context,
      title: l10n.export.restoreFromBackup,
      message: l10n.export.restoreConfirmMessage,
      confirmLabel: l10n.export.restoreConfirmLabel,
    );
    if (!confirmed) return;

    toast.loading(message: l10n.export.restoring);
    try {
      final result = await IBackupArchive.get().import(file.path);
      await toast.dismiss();
      final base = l10n.export.restoreSummary(
        diary: result.diaryCount,
        category: result.categoryCount,
        media: result.mediaInfoCount,
      );
      final summary = result.failed > 0
          ? l10n.export.restoreSummaryFailed(base: base, failed: result.failed)
          : base;
      if (result.cancelled) {
        // 半截恢复不能报成功——用户可能据此认为数据已齐。
        toast.error(message: l10n.export.restoreStopped(summary: summary));
      } else {
        toast.success(message: l10n.export.restoreDone(summary: summary));
      }
    } catch (e) {
      await toast.dismiss();
      toast.error(message: l10n.export.restoreFailed(error: '$e'));
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    final l10n = context.l10n;
    toast.loading(message: l10n.export.packingBackup);
    final String zipPath;
    try {
      zipPath = await IBackupArchive.get().export();
      await toast.dismiss();
    } catch (e) {
      await toast.dismiss();
      toast.error(message: l10n.export.failed(error: '$e'));
      return;
    }
    await _share(zipPath, 'application/zip', l10n.export.backupReady);
  }

  @override
  Widget build(BuildContext context) {
    return MSliverSettingGroup(
      title: context.l10n.export.sectionBackup,
      children: [
        SettingListTile(
          title: context.l10n.export.backupExport,
          subtitle: context.l10n.export.backupExportSubtitle,
          leading: const Icon(LucideIcons.archive),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => _exportBackup(context),
        ),
        SettingListTile(
          title: context.l10n.export.restoreFromBackup,
          subtitle: context.l10n.export.backupRestoreSubtitle,
          leading: const Icon(LucideIcons.archiveRestore),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => _restoreBackup(context),
        ),
      ],
    );
  }
}

/// 把产物交给系统分享面板；不可用时退回「路径已复制」提示。
Future<void> _share(String path, String mime, String successMessage) async {
  try {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path, mimeType: mime)]),
    );
  } catch (_) {
    toast.info(message: '$successMessage: $path');
  }
}

Future<void> shareExported(String path, Translations l10n) async {
  final mime = switch (path.split('.').last.toLowerCase()) {
    'md' => 'text/markdown',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'pdf' => 'application/pdf',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
  if (!File(path).existsSync()) {
    toast.error(message: l10n.export.artifactMissing);
    return;
  }
  await _share(path, mime, l10n.export.generated);
}
