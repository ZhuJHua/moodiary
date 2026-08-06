import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

import '../data/export_options.dart';
import '../data/markdown_writer.dart';
import '../data/export_scope.dart';
import '../data/export_service.dart';
import 'export_page.dart' show shareExported;
import 'pdf_font_page.dart';
import 'scope_picker_page.dart';

/// 一种格式的导出配置。三种格式共用这一页 —— 差别只在「排版」分组的内容，
/// 各写一页会让「范围 / 内容」两组逻辑复制三份、慢慢漂移。
class FormatExportPage extends StatefulWidget {
  final ExportFormat format;

  const FormatExportPage({super.key, required this.format});

  @override
  State<FormatExportPage> createState() => _FormatExportPageState();
}

class _FormatExportPageState extends State<FormatExportPage> {
  late ExportSettings _settings = ExportSettings.decode(
    MoodiaryKVs.exportSettings.get() ?? '',
  );

  ExportScope _scope = const AllDiariesScope();
  int? _scopeCount;
  bool _running = false;
  ExportProgress? _progress;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final diaries = await _scope.resolve();
    if (mounted) setState(() => _scopeCount = diaries.length);
  }

  void _update(ExportSettings next) {
    setState(() => _settings = next);
    MoodiaryKVs.exportSettings.set(next.encode());
  }

  ExportCommon get _common => _settings.common;

  LayoutExportOptions get _layout =>
      widget.format == ExportFormat.pdf ? _settings.pdf : _settings.docx;

  void _updateLayout(LayoutExportOptions next) => _update(
    widget.format == ExportFormat.pdf
        ? _settings.copyWith(pdf: next)
        : _settings.copyWith(docx: next),
  );

  String _titleOf(AppLocalizations l10n) => switch (widget.format) {
    ExportFormat.markdown => l10n.exportTitleMarkdown,
    ExportFormat.docx => l10n.exportTitleDocx,
    ExportFormat.pdf => l10n.exportTitlePdf,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titleOf(context.l10n))),
      body: ListView(
        // 底部有操作栏吃安全区，这里只补常规内边距。
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          _scopeSection(),
          const SizedBox(height: 4),
          _contentSection(),
          const SizedBox(height: 4),
          if (widget.format == ExportFormat.markdown) _markdownSection(),
          if (widget.format != ExportFormat.markdown) _layoutSection(),
        ],
      ),
      bottomNavigationBar: _actionBar(),
    );
  }

  // ---------------------------------------------------------------- 范围

  Widget _scopeSection() {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingTitleTile(title: l10n.exportSectionScope),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              SettingListTile(
                isFirst: true,
                title: l10n.exportSelectDiaries,
                subtitle: _scopeLabel(l10n),
                leading: const Icon(LucideIcons.calendarRange),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _scopeCount == null
                          ? l10n.exportCounting
                          : l10n.exportEntryCount(_scopeCount!),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight),
                  ],
                ),
                onTap: _pickScope,
              ),
              SwitchListTile(
                value: _common.merge,
                title: Text(l10n.exportMergeIntoOneFile),
                subtitle: Text(l10n.exportMergeSubtitle),
                secondary: const Icon(LucideIcons.package),
                onChanged: (v) =>
                    _update(_settings.copyWith(common: _common.copyWith(merge: v))),
              ),
              if (!_common.merge)
                SettingListTile(
                  isLast: true,
                  title: l10n.exportFileName,
                  subtitle: _common.nameTemplate,
                  leading: const Icon(LucideIcons.type),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: _editNameTemplate,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickScope() async {
    final picked = await Navigator.of(context).push<ExportScope>(
      MaterialPageRoute(builder: (_) => ScopePickerPage(initial: _scope)),
    );
    if (picked == null) return;
    setState(() {
      _scope = picked;
      _scopeCount = null;
    });
    await _refreshCount();
  }

  Future<void> _editNameTemplate() async {
    final l10n = context.l10n;
    final value = await showMoodiaryPrompt(
      context,
      title: l10n.exportFileNameTemplate,
      // 花括号是模板语法本身，作为字面量传进占位符 —— gen-l10n 的 ICU 不支持转义花括号。
      message: l10n.exportFileNameTemplateHint('{date}', '{id}', '{title}'),
      initialValue: _common.nameTemplate,
      validator: (v) => v.trim().isEmpty ? l10n.exportTemplateEmpty : null,
    );
    if (value == null) return;
    _update(_settings.copyWith(common: _common.copyWith(nameTemplate: value)));
  }

  // ---------------------------------------------------------------- 内容

  Widget _contentSection() {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingTitleTile(title: l10n.exportSectionContent),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                value: _common.includeTitle,
                title: Text(l10n.exportIncludeTitle),
                secondary: const Icon(LucideIcons.heading),
                onChanged: (v) => _update(
                  _settings.copyWith(common: _common.copyWith(includeTitle: v)),
                ),
              ),
              SwitchListTile(
                value: _common.includeMeta,
                title: Text(l10n.exportIncludeMeta),
                secondary: const Icon(LucideIcons.info),
                onChanged: (v) => _update(
                  _settings.copyWith(common: _common.copyWith(includeMeta: v)),
                ),
              ),
              SettingListTile(
                isLast: true,
                title: l10n.exportMedia,
                subtitle: _mediaLabel(l10n, _common.media),
                leading: const Icon(LucideIcons.image),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: _pickMedia,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _mediaLabel(AppLocalizations l10n, ExportMediaPolicy policy) =>
      switch (policy) {
        ExportMediaPolicy.embed => l10n.exportMediaEmbed,
        ExportMediaPolicy.placeholder => l10n.exportMediaPlaceholder,
        ExportMediaPolicy.none => l10n.exportMediaNone,
      };

  /// 范围描述：成句的部分走 l10n，分类名 / 日期区间这类用户数据由 scope 自己带。
  String _scopeLabel(AppLocalizations l10n) {
    final detail = _scope.detail;
    return switch (_scope.kind) {
      ExportScopeKind.all => l10n.exportScopeAll,
      ExportScopeKind.category => detail ?? l10n.exportScopeByCategory,
      ExportScopeKind.dateRange => detail ?? l10n.exportScopeByDate,
      ExportScopeKind.picked =>
        l10n.exportScopePickedLabel(_scopeCount ?? 0),
    };
  }

  Future<void> _pickMedia() async {
    final l10n = context.l10n;
    final picked = await showMoodiaryAlert<ExportMediaPolicy>(
      context,
      title: l10n.exportMedia,
      actions: [
        for (final policy in ExportMediaPolicy.values)
          MoodiaryAction(
            label: _mediaLabel(l10n, policy),
            value: policy,
            isPrimary: policy == _common.media,
          ),
      ],
    );
    if (picked == null) return;
    _update(_settings.copyWith(common: _common.copyWith(media: picked)));
  }

  // ------------------------------------------------------------ Markdown

  Widget _markdownSection() {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final md = _settings.markdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingTitleTile(title: 'Markdown'),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                value: md.dialect == MarkdownDialect.gfm,
                title: Text(l10n.exportMarkdownGfm),
                subtitle: Text(l10n.exportMarkdownGfmSubtitle),
                secondary: const Icon(LucideIcons.fileJson),
                onChanged: (v) => _update(
                  _settings.copyWith(
                    markdown: md.copyWith(
                      dialect: v ? MarkdownDialect.gfm : MarkdownDialect.commonMark,
                    ),
                  ),
                ),
              ),
              SwitchListTile(
                value: md.frontMatter,
                title: Text(l10n.exportMarkdownFrontMatter),
                subtitle: Text(l10n.exportMarkdownFrontMatterSubtitle),
                secondary: const Icon(LucideIcons.fileInput),
                onChanged: (v) => _update(
                  _settings.copyWith(markdown: md.copyWith(frontMatter: v)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 排版

  Widget _layoutSection() {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final layout = _layout;
    final isPdf = widget.format == ExportFormat.pdf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingTitleTile(title: l10n.exportSectionLayout),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              SettingListTile(
                isFirst: true,
                title: isPdf ? l10n.exportFont : l10n.exportEastAsiaFont,
                subtitle: isPdf && layout.eastAsiaFont.isEmpty
                    ? l10n.exportNoFontSelected
                    : layout.eastAsiaFont,
                leading: const Icon(LucideIcons.type),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: isPdf ? _pickPdfFont : () => _editFontName(eastAsia: true),
              ),
              if (!isPdf)
                SettingListTile(
                  title: l10n.exportAsciiFont,
                  subtitle: layout.asciiFont,
                  leading: const Icon(LucideIcons.type),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => _editFontName(eastAsia: false),
                ),
              SettingListTile(
                title: l10n.exportFontSize,
                subtitle: l10n.exportFontSizeValue(layout.fontSizePt.toStringAsFixed(0)),
                leading: const Icon(LucideIcons.aLargeSmall),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: _pickFontSize,
              ),
              SettingListTile(
                title: l10n.exportLineSpacing,
                subtitle: l10n.exportLineSpacingValue(layout.lineSpacing.toStringAsFixed(1)),
                leading: const Icon(LucideIcons.alignJustify),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: _pickLineSpacing,
              ),
              SwitchListTile(
                value: layout.firstLineIndent,
                title: Text(l10n.exportFirstLineIndent),
                secondary: const Icon(LucideIcons.indentIncrease),
                onChanged: (v) =>
                    _updateLayout(layout.copyWith(firstLineIndent: v)),
              ),
              SettingListTile(
                isLast: true,
                title: l10n.exportPaper,
                subtitle: layout.paper.label,
                leading: const Icon(LucideIcons.layoutTemplate),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: _pickPaper,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editFontName({required bool eastAsia}) async {
    final l10n = context.l10n;
    final value = await showMoodiaryPrompt(
      context,
      title: eastAsia ? l10n.exportEastAsiaFont : l10n.exportAsciiFont,
      message: l10n.exportFontNameHint,
      initialValue: eastAsia ? _layout.eastAsiaFont : _layout.asciiFont,
      validator: (v) => v.trim().isEmpty ? l10n.exportFontNameEmpty : null,
    );
    if (value == null) return;
    _updateLayout(
      eastAsia
          ? _layout.copyWith(eastAsiaFont: value)
          : _layout.copyWith(asciiFont: value),
    );
  }

  Future<void> _pickPdfFont() async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PdfFontPage(selected: _settings.pdf.eastAsiaFont),
      ),
    );
    if (picked == null) return;
    _update(_settings.copyWith(pdf: _settings.pdf.copyWith(eastAsiaFont: picked)));
  }

  Future<void> _pickFontSize() async {
    final l10n = context.l10n;
    final picked = await _pickFrom<double>(
      title: l10n.exportFontSize,
      values: const [9.0, 10.0, 11.0, 12.0, 14.0, 16.0],
      current: _layout.fontSizePt,
      label: (v) => l10n.exportFontSizeValue(v.toStringAsFixed(0)),
    );
    if (picked != null) _updateLayout(_layout.copyWith(fontSizePt: picked));
  }

  Future<void> _pickLineSpacing() async {
    final l10n = context.l10n;
    final picked = await _pickFrom<double>(
      title: l10n.exportLineSpacing,
      values: const [1.0, 1.15, 1.5, 1.75, 2.0],
      current: _layout.lineSpacing,
      label: (v) => l10n.exportLineSpacingValue(v.toStringAsFixed(2)),
    );
    if (picked != null) _updateLayout(_layout.copyWith(lineSpacing: picked));
  }

  Future<void> _pickPaper() async {
    final picked = await _pickFrom<ExportPaper>(
      title: context.l10n.exportPaper,
      values: ExportPaper.values,
      current: _layout.paper,
      label: (v) => v.label,
    );
    if (picked != null) _updateLayout(_layout.copyWith(paper: picked));
  }

  Future<T?> _pickFrom<T>({
    required String title,
    required List<T> values,
    required T current,
    required String Function(T) label,
  }) => showMoodiaryAlert<T>(
    context,
    title: title,
    actions: [
      for (final value in values)
        MoodiaryAction(
          label: label(value),
          value: value,
          isPrimary: value == current,
        ),
    ],
  );

  // ---------------------------------------------------------------- 执行

  Widget _actionBar() {
    final l10n = context.l10n;
    final count = _scopeCount;
    final blocked = _pdfBlockedReason();
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (blocked != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                blocked,
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.error,
                ),
              ),
            ),
          if (_running && _progress != null) _progressBar(_progress!, l10n),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: (_running || count == null || count == 0 || blocked != null)
                  ? null
                  : _run,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.download),
              label: Text(
                count == null
                    ? l10n.exportCounting
                    : (count == 0
                          ? l10n.exportScopeEmpty
                          : l10n.exportRunButton(count)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBar(ExportProgress progress, AppLocalizations l10n) {
    final label = switch (progress.phase) {
      ExportPhase.converting => l10n.exportProgressConverting(
        progress.done,
        progress.total,
      ),
      ExportPhase.writing when progress.total == 0 => l10n.exportProgressWriting,
      ExportPhase.writing => l10n.exportProgressWritingCount(
        progress.done,
        progress.total,
      ),
      // 收尾阶段切不开，只能给不确定进度条。
      ExportPhase.serializing => l10n.exportProgressSerializing,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: progress.total == 0
                  ? null
                  : progress.done / progress.total,
            ),
          ),
        ],
      ),
    );
  }

  /// PDF 必须先有一个可用的字体，否则导出会在写文件那一步才失败。
  String? _pdfBlockedReason() {
    if (widget.format != ExportFormat.pdf) return null;
    if (_settings.pdf.eastAsiaFont.isEmpty) return context.l10n.exportPickFontFirst;
    return null;
  }

  Future<void> _run() async {
    final l10n = context.l10n;
    setState(() {
      _running = true;
      _progress = const ExportProgress(ExportPhase.converting, 0, 1);
    });
    try {
      final outcome = await ExportService.run(
        format: widget.format,
        scope: _scope,
        settings: _settings,
        untitledLabel: l10n.exportUntitled,
        videoLabel: l10n.exportMediaKindVideo,
        audioLabel: l10n.exportMediaKindAudio,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) await _reportAndShare(outcome, l10n);
    } on ExportException catch (e) {
      toast.error(
        message: switch (e.error) {
          ExportError.emptyScope => l10n.exportScopeEmpty,
        },
      );
    } catch (e) {
      toast.error(message: l10n.exportFailed('$e'));
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _reportAndShare(ExportOutcome outcome, AppLocalizations l10n) async {
    final notes = [
      if (outcome.skippedMedia > 0) l10n.exportSkippedMedia(outcome.skippedMedia),
      if (outcome.unsupportedNodes.isNotEmpty)
        l10n.exportUnsupportedNodes(
          outcome.unsupportedNodes.length,
          outcome.unsupportedNodes.join('、'),
        ),
    ];
    if (notes.isNotEmpty && mounted) {
      await showMoodiaryNotice(
        context,
        title: l10n.exportPartialTitle,
        message: notes.join('\n'),
      );
    }
    await shareExported(outcome.path, l10n);
  }
}

