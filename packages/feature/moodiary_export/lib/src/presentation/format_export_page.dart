import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_rust/foundation.dart' as rust;
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

import '../data/export_options.dart';
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
  late ExportSettings _settings = .decode(
    MoodiaryKVs.exportSettings.get() ?? '',
  );

  ExportScope _scope = const AllDiariesScope();
  int? _scopeCount;
  bool _running = false;
  ExportProgress? _progress;
  rust.CancelToken? _cancel;

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
      widget.format == .pdf ? _settings.pdf : _settings.docx;

  void _updateLayout(LayoutExportOptions next) => _update(
    widget.format == .pdf
        ? _settings.copyWith(pdf: next)
        : _settings.copyWith(docx: next),
  );

  String _titleOf(Translations l10n) => switch (widget.format) {
    .markdown => l10n.export.titleMarkdown,
    .docx => l10n.export.titleDocx,
    .pdf => l10n.export.titlePdf,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titleOf(context.l10n))),
      body: ListView(
        // 底部有操作栏吃安全区，这里只补常规内边距。
        padding: const .symmetric(horizontal: 8, vertical: 8),
        children: [
          _scopeSection(),
          const SizedBox(height: 4),
          _contentSection(),
          const SizedBox(height: 4),
          if (widget.format == .markdown) _markdownSection(),
          if (widget.format != .markdown) _layoutSection(),
        ],
      ),
      bottomNavigationBar: _actionBar(),
    );
  }

  // ---------------------------------------------------------------- 范围

  Widget _scopeSection() {
    final l10n = context.l10n;
    final theme = context.theme;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: l10n.export.sectionScope),
        Card.filled(
          color: theme.colors.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SettingListTile(
                isFirst: true,
                title: l10n.export.selectDiaries,
                subtitle: _scopeLabel(l10n),
                leading: const Icon(LucideIcons.calendarRange),
                trailing: Row(
                  mainAxisSize: .min,
                  children: [
                    Text(
                      _scopeCount == null
                          ? l10n.export.counting
                          : l10n.export.entryCount(count: _scopeCount!),
                      style: theme.typography.bodySmall.onSurfaceVariant,
                    ),
                    const Icon(LucideIcons.chevronRight),
                  ],
                ),
                onTap: _pickScope,
              ),
              SwitchListTile(
                value: _common.merge,
                title: Text(l10n.export.mergeIntoOneFile),
                subtitle: Text(l10n.export.mergeSubtitle),
                secondary: const Icon(LucideIcons.package),
                onChanged: (v) => _update(
                  _settings.copyWith(common: _common.copyWith(merge: v)),
                ),
              ),
              if (!_common.merge)
                SettingListTile(
                  isLast: true,
                  title: l10n.common.fileName,
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
    final value = await MAlert.prompt(
      context,
      title: l10n.export.fileNameTemplate,
      // 花括号是模板语法本身，作为字面量传进占位符 —— 文案里的 `{x}` 会被 slang 当参数吃掉。
      message: l10n.export.fileNameTemplateHint(
        date: '{date}',
        title: '{title}',
        id: '{id}',
      ),
      initialValue: _common.nameTemplate,
      validator: (v) => v.trim().isEmpty ? l10n.export.templateEmpty : null,
    );
    if (value == null) return;
    _update(_settings.copyWith(common: _common.copyWith(nameTemplate: value)));
  }

  // ---------------------------------------------------------------- 内容

  Widget _contentSection() {
    final l10n = context.l10n;
    final theme = context.theme;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: l10n.export.sectionContent),
        Card.filled(
          color: theme.colors.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SwitchListTile(
                value: _common.includeTitle,
                title: Text(l10n.export.includeTitle),
                secondary: const Icon(LucideIcons.heading),
                onChanged: (v) => _update(
                  _settings.copyWith(common: _common.copyWith(includeTitle: v)),
                ),
              ),
              SwitchListTile(
                value: _common.includeMeta,
                title: Text(l10n.export.includeMeta),
                secondary: const Icon(LucideIcons.info),
                onChanged: (v) => _update(
                  _settings.copyWith(common: _common.copyWith(includeMeta: v)),
                ),
              ),
              SettingListTile(
                isLast: true,
                title: l10n.common.media,
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

  static String _mediaLabel(Translations l10n, ExportMediaPolicy policy) =>
      switch (policy) {
        .embed => l10n.export.mediaEmbed,
        .placeholder => l10n.export.mediaPlaceholder,
        .none => l10n.export.mediaNone,
      };

  /// 范围描述：成句的部分走 l10n，分类名 / 日期区间这类用户数据由 scope 自己带。
  String _scopeLabel(Translations l10n) {
    final detail = _scope.detail;
    return switch (_scope.kind) {
      .all => l10n.export.scopeAll,
      .category => detail ?? l10n.export.scopeByCategory,
      .dateRange => detail ?? l10n.export.scopeByDate,
      .picked => l10n.export.scopePickedLabel(count: _scopeCount ?? 0),
    };
  }

  Future<void> _pickMedia() async {
    final l10n = context.l10n;
    final picked = await MAlert.show<ExportMediaPolicy>(
      context,
      title: l10n.common.media,
      actions: [
        for (final policy in ExportMediaPolicy.values)
          MAction(
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
    final theme = context.theme;
    final md = _settings.markdown;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const SettingTitleTile(title: 'Markdown'),
        Card.filled(
          color: theme.colors.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SwitchListTile(
                value: md.dialect == .gfm,
                title: Text(l10n.export.markdownGfm),
                subtitle: Text(l10n.export.markdownGfmSubtitle),
                secondary: const Icon(LucideIcons.fileJson),
                onChanged: (v) => _update(
                  _settings.copyWith(
                    markdown: md.copyWith(dialect: v ? .gfm : .commonMark),
                  ),
                ),
              ),
              SwitchListTile(
                value: md.frontMatter,
                title: Text(l10n.export.markdownFrontMatter),
                subtitle: Text(l10n.export.markdownFrontMatterSubtitle),
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
    final theme = context.theme;
    final layout = _layout;
    final isPdf = widget.format == .pdf;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: l10n.export.sectionLayout),
        Card.filled(
          color: theme.colors.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SettingListTile(
                isFirst: true,
                title: isPdf ? l10n.export.font : l10n.export.eastAsiaFont,
                subtitle: isPdf && layout.eastAsiaFont.isEmpty
                    ? l10n.export.noFontSelected
                    : layout.eastAsiaFont,
                leading: const Icon(LucideIcons.type),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: isPdf
                    ? _pickPdfFont
                    : () => _editFontName(eastAsia: true),
              ),
              if (!isPdf)
                SettingListTile(
                  title: l10n.export.asciiFont,
                  subtitle: layout.asciiFont,
                  leading: const Icon(LucideIcons.type),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => _editFontName(eastAsia: false),
                ),
              SettingListTile(
                title: l10n.export.fontSize,
                subtitle: l10n.export.fontSizeValue(
                  size: layout.fontSizePt.toStringAsFixed(0),
                ),
                leading: const Icon(LucideIcons.aLargeSmall),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: _pickFontSize,
              ),
              SettingListTile(
                title: l10n.export.lineSpacing,
                subtitle: l10n.export.lineSpacingValue(
                  value: layout.lineSpacing.toStringAsFixed(1),
                ),
                leading: const Icon(LucideIcons.alignJustify),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: _pickLineSpacing,
              ),
              SwitchListTile(
                value: layout.firstLineIndent,
                title: Text(l10n.export.firstLineIndent),
                secondary: const Icon(LucideIcons.indentIncrease),
                onChanged: (v) =>
                    _updateLayout(layout.copyWith(firstLineIndent: v)),
              ),
              SettingListTile(
                isLast: true,
                title: l10n.export.paper,
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
    final value = await MAlert.prompt(
      context,
      title: eastAsia ? l10n.export.eastAsiaFont : l10n.export.asciiFont,
      message: l10n.export.fontNameHint,
      initialValue: eastAsia ? _layout.eastAsiaFont : _layout.asciiFont,
      validator: (v) => v.trim().isEmpty ? l10n.export.fontNameEmpty : null,
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
    _update(
      _settings.copyWith(pdf: _settings.pdf.copyWith(eastAsiaFont: picked)),
    );
  }

  Future<void> _pickFontSize() async {
    final l10n = context.l10n;
    final picked = await _pickFrom<double>(
      title: l10n.export.fontSize,
      values: const [9.0, 10.0, 11.0, 12.0, 14.0, 16.0],
      current: _layout.fontSizePt,
      label: (v) => l10n.export.fontSizeValue(size: v.toStringAsFixed(0)),
    );
    if (picked != null) _updateLayout(_layout.copyWith(fontSizePt: picked));
  }

  Future<void> _pickLineSpacing() async {
    final l10n = context.l10n;
    final picked = await _pickFrom<double>(
      title: l10n.export.lineSpacing,
      values: const [1.0, 1.15, 1.5, 1.75, 2.0],
      current: _layout.lineSpacing,
      label: (v) => l10n.export.lineSpacingValue(value: v.toStringAsFixed(2)),
    );
    if (picked != null) _updateLayout(_layout.copyWith(lineSpacing: picked));
  }

  Future<void> _pickPaper() async {
    final picked = await _pickFrom<ExportPaper>(
      title: context.l10n.export.paper,
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
  }) => MAlert.show<T>(
    context,
    title: title,
    actions: [
      for (final value in values)
        MAction(label: label(value), value: value, isPrimary: value == current),
    ],
  );

  // ---------------------------------------------------------------- 执行

  Widget _actionBar() {
    final l10n = context.l10n;
    final count = _scopeCount;
    final blocked = _pdfBlockedReason();
    return SafeArea(
      minimum: const .fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          if (blocked != null)
            Padding(
              padding: const .only(bottom: 8),
              child: Text(
                blocked,
                textAlign: .center,
                style: context.theme.typography.bodySmall.error,
              ),
            ),
          if (_running && _progress != null) _progressBar(_progress!, l10n),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: .circular(14)),
              ),
              onPressed: _running
                  ? _cancelRun
                  : ((count == null || count == 0 || blocked != null)
                        ? null
                        : _run),
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.download),
              label: Text(
                _running
                    ? l10n.common.cancel
                    : (count == null
                          ? l10n.export.counting
                          : (count == 0
                                ? l10n.export.scopeEmpty
                                : l10n.export.runButton(count: count))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBar(ExportProgress progress, Translations l10n) {
    final label = switch (progress.phase) {
      .converting => l10n.export.progressConverting(
        done: progress.done,
        total: progress.total,
      ),
      .writing when progress.total == 0 => l10n.export.progressWriting,
      .writing => l10n.export.progressWritingCount(
        done: progress.done,
        total: progress.total,
      ),
      // 收尾阶段切不开，只能给不确定进度条。
      .serializing => l10n.export.progressSerializing,
    };
    return Padding(
      padding: const .only(bottom: 10),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Text(
            label,
            textAlign: .center,
            style: context.theme.typography.bodySmall.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: .circular(3),
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
    if (widget.format != .pdf) return null;
    if (_settings.pdf.eastAsiaFont.isEmpty) {
      return context.l10n.export.pickFontFirst;
    }
    return null;
  }

  void _cancelRun() => _cancel?.cancel();

  Future<void> _run() async {
    final l10n = context.l10n;
    final token = rust.CancelToken();
    setState(() {
      _running = true;
      _cancel = token;
      _progress = const ExportProgress(.converting, 0, 1);
    });
    try {
      final outcome = await ExportService.run(
        cancel: token,
        format: widget.format,
        scope: _scope,
        settings: _settings,
        untitledLabel: l10n.common.untitled,
        videoLabel: l10n.common.video,
        audioLabel: l10n.common.audio,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) await _reportAndShare(outcome, l10n);
    } on ExportException catch (e) {
      toast.error(
        message: switch (e.error) {
          .emptyScope => l10n.export.scopeEmpty,
          .cancelled => l10n.export.cancelled,
        },
      );
    } catch (e) {
      toast.error(message: l10n.export.failed(error: '$e'));
    } finally {
      token.dispose();
      if (mounted) {
        setState(() {
          _running = false;
          _cancel = null;
          _progress = null;
        });
      }
    }
  }

  Future<void> _reportAndShare(ExportOutcome outcome, Translations l10n) async {
    final notes = [
      if (outcome.skippedMedia > 0)
        l10n.export.skippedMedia(count: outcome.skippedMedia),
      if (outcome.unsupportedNodes.isNotEmpty)
        l10n.export.unsupportedNodes(
          count: outcome.unsupportedNodes.length,
          types: outcome.unsupportedNodes.join('、'),
        ),
    ];
    if (notes.isNotEmpty && mounted) {
      await MAlert.notice(
        context,
        title: l10n.export.partialTitle,
        message: notes.join('\n'),
      );
    }
    await shareExported(outcome.path, l10n);
  }
}
