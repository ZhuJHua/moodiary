import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
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
      appBar: AppBar(title: Text(context.l10n.exportPageTitle)),
      body: ListView(
        // 与其它设置页一致：左右 8、上下 8，再补底部安全区。
        padding: .fromLTRB(8, 8, 8, 8 + MediaQuery.paddingOf(context).bottom),
        children: const [
          _ExportSection(),
          SizedBox(height: 4),
          _ImportSection(),
        ],
      ),
    );
  }
}

class _ExportSection extends StatelessWidget {
  const _ExportSection();

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.exportSectionExport),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SettingListTile(
                isFirst: true,
                title: 'Markdown',
                leading: const FileTypeIcon('MD'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _open(context, .markdown),
              ),
              SettingListTile(
                title: context.l10n.exportFormatDocx,
                leading: const FileTypeIcon('DOCX'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _open(context, .docx),
              ),
              SettingListTile(
                isLast: true,
                title: 'PDF',
                leading: const FileTypeIcon('PDF'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _open(context, .pdf),
              ),
            ],
          ),
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
      title: l10n.exportRestoreFromBackup,
      message: l10n.exportRestoreConfirmMessage,
      confirmLabel: l10n.exportRestoreConfirmLabel,
    );
    if (!confirmed) return;

    toast.loading(message: l10n.exportRestoring);
    try {
      final summary = await IBackupArchive.get().import(file.path);
      await toast.dismiss();
      toast.success(message: l10n.exportRestoreDone(summary));
    } catch (e) {
      await toast.dismiss();
      toast.error(message: l10n.exportRestoreFailed('$e'));
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    final l10n = context.l10n;
    toast.loading(message: l10n.exportPackingBackup);
    final String zipPath;
    try {
      zipPath = await IBackupArchive.get().export();
      await toast.dismiss();
    } catch (e) {
      await toast.dismiss();
      toast.error(message: l10n.exportFailed('$e'));
      return;
    }
    await _share(zipPath, 'application/zip', l10n.exportBackupReady);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.exportSectionBackup),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SettingListTile(
                isFirst: true,
                title: context.l10n.exportBackupExport,
                subtitle: context.l10n.exportBackupExportSubtitle,
                leading: const Icon(LucideIcons.archive),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _exportBackup(context),
              ),
              SettingListTile(
                isLast: true,
                title: context.l10n.exportRestoreFromBackup,
                subtitle: context.l10n.exportBackupRestoreSubtitle,
                leading: const Icon(LucideIcons.archiveRestore),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _restoreBackup(context),
              ),
            ],
          ),
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

Future<void> shareExported(String path, AppLocalizations l10n) async {
  final mime = switch (path.split('.').last.toLowerCase()) {
    'md' => 'text/markdown',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'pdf' => 'application/pdf',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
  if (!File(path).existsSync()) {
    toast.error(message: l10n.exportArtifactMissing);
    return;
  }
  await _share(path, mime, l10n.exportGenerated);
}
