import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';
import 'package:path/path.dart' as p;

import '../data/import/import_media_stage.dart';
import '../data/import/import_source.dart';
import '../data/import/markdown_importer.dart';

/// 「从 Markdown 导入」：选包 → 看到篇数 → 导入 → 报告。骨架照 FormatExportPage。
class MarkdownImportPage extends StatefulWidget {
  const MarkdownImportPage({super.key});

  @override
  State<MarkdownImportPage> createState() => _MarkdownImportPageState();
}

class _MarkdownImportPageState extends State<MarkdownImportPage> {
  MarkdownImportSource? _source;
  String? _fileName;
  bool _scanning = false;
  bool _running = false;
  bool _cancelRequested = false;
  (int, int)? _progress;

  @override
  void dispose() {
    _source?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.export.importTitle)),
      body: ListView(
        padding: const .symmetric(horizontal: 8, vertical: 8),
        children: [_fileSection(), const SizedBox(height: 4), _specSection()],
      ),
      bottomNavigationBar: _actionBar(),
    );
  }

  Widget _fileSection() {
    final l10n = context.l10n;
    final theme = context.theme;
    final count = _source?.count;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: l10n.export.importSectionFile),
        Card.filled(
          color: theme.colors.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SettingListTile(
                isFirst: true,
                isLast: true,
                title: l10n.export.importPickFile,
                subtitle: _fileName ?? l10n.export.importNoFile,
                leading: const FileTypeIcon('MD'),
                trailing: Row(
                  mainAxisSize: .min,
                  children: [
                    if (_scanning)
                      Text(
                        l10n.export.importScanning,
                        style: theme.typography.bodySmall.onSurfaceVariant,
                      )
                    else if (count != null)
                      Text(
                        l10n.export.importDetected(count: count),
                        style: theme.typography.bodySmall.onSurfaceVariant,
                      ),
                    const Icon(LucideIcons.chevronRight),
                  ],
                ),
                onTap: _running || _scanning ? null : _pickFile,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 规范直接摆在页面上：用户要照着它造包，藏进弹窗就得来回翻。
  Widget _specSection() {
    final l10n = context.l10n;
    final theme = context.theme;
    final body = theme.typography.bodyMedium.onSurface;
    final mono = theme.typography.bodySmall.onSurfaceVariant.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Courier New', 'monospace'],
      height: 1.5,
    );
    final lines = [
      l10n.export.importSpecEntries,
      l10n.export.importSpecAssets,
      l10n.export.importSpecFrontMatter,
      l10n.export.importSpecRoundTrip,
    ];
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: l10n.export.importSpec),
        Card.filled(
          color: theme.colors.surfaceContainerLow,
          margin: .zero,
          child: Padding(
            padding: const .fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                for (final (i, line) in lines.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: .start,
                    children: [
                      Text('${i + 1}.', style: body),
                      const SizedBox(width: 6),
                      Expanded(child: Text(line, style: body)),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const .symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colors.surfaceContainerHigh,
                    borderRadius: .circular(10),
                  ),
                  child: Text(l10n.export.importSpecExample, style: mono),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    final l10n = context.l10n;
    final file = await getIt<IFilePicker>().pickFile(
      allowedExtensions: ['zip', 'md'],
    );
    if (file == null || !mounted) return;

    final previous = _source;
    setState(() {
      _scanning = true;
      _source = null;
      _fileName = p.basename(file.path);
    });
    await previous?.dispose();
    try {
      final source = await MarkdownImportSource.open(file.path);
      if (!mounted) {
        await source.dispose();
        return;
      }
      setState(() => _source = source);
      if (source.count == 0) toast.info(message: l10n.export.importEmpty);
    } catch (e) {
      toast.error(message: l10n.export.importRunFailed(error: '$e'));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Widget _actionBar() {
    final l10n = context.l10n;
    final count = _source?.count ?? 0;
    return SafeArea(
      minimum: const .fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          if (_running && _progress != null) _progressBar(_progress!, l10n),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _running
                  ? _cancelRun
                  : (count == 0 || _scanning ? null : _run),
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.fileInput, size: 18),
              label: Text(
                _running
                    ? l10n.common.cancel
                    : (count == 0
                          ? l10n.export.importPickFile
                          : l10n.export.importRunButton(count: count)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBar((int, int) progress, Translations l10n) {
    final (done, total) = progress;
    return Padding(
      padding: const .only(bottom: 10),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Text(
            l10n.export.importProgress(done: done, total: total),
            textAlign: .center,
            style: context.theme.typography.bodySmall.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: .circular(3),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: total == 0 ? null : done / total,
            ),
          ),
        ],
      ),
    );
  }

  void _cancelRun() => _cancelRequested = true;

  Future<void> _run() async {
    final l10n = context.l10n;
    final source = _source;
    if (source == null) return;
    setState(() {
      _running = true;
      _cancelRequested = false;
      _progress = (0, source.count);
    });
    try {
      final importer = MarkdownImporter(
        diaries: getIt<DiaryRepository>(),
        categories: getIt<CategoryRepository>(),
        places: getIt<PlaceRepository>(),
        media: const AppImportMediaStore(),
      );
      final report = await importer.run(
        source,
        isCancelled: () => _cancelRequested,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = (done, total));
        },
      );
      if (mounted) await _report(report, l10n);
    } catch (e) {
      toast.error(message: l10n.export.importRunFailed(error: '$e'));
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _progress = null;
        });
      }
    }
  }

  /// 报法同「从备份恢复」：有失败不能走绿色，中途停止更不能。
  Future<void> _report(MarkdownImportReport report, Translations l10n) async {
    final base = l10n.export.importSummary(
      diary: report.diaries,
      category: report.categories,
      place: report.places,
    );
    final withSkipped = report.skipped > 0
        ? l10n.export.importSummarySkipped(base: base, skipped: report.skipped)
        : base;
    final summary = report.failed > 0
        ? l10n.export.importSummaryFailed(
            base: withSkipped,
            failed: report.failed,
          )
        : withSkipped;
    if (report.cancelled) {
      toast.error(message: l10n.export.importStopped(summary: summary));
    } else if (report.failed > 0) {
      toast.error(message: l10n.export.importPartial(summary: summary));
    } else {
      toast.success(message: l10n.export.importDone(summary: summary));
    }
    if (report.missingMedia > 0 && mounted) {
      await MAlert.notice(
        context,
        title: l10n.export.importTitle,
        message: l10n.export.importMissingMedia(count: report.missingMedia),
      );
    }
    // 包已经用完，工作目录不必等到离开页面再清。
    await _source?.dispose();
    if (mounted) {
      setState(() {
        _source = null;
        _fileName = null;
      });
    }
  }
}
