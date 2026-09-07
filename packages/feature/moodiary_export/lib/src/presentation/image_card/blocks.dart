import 'dart:ui' as ui;

import 'package:moodiary_components/moodiary_components.dart';

import '../../data/export_doc.dart';
import 'card_style.dart';

class IrBlockRenderer {
  final ImageCardStyle style;

  final Map<String, ui.Image> images;

  static final Highlight _highlighter = codeHighlighter;

  const IrBlockRenderer({required this.style, required this.images});

  List<Widget> blocks(List<IrBlock> blocks) {
    final out = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      out.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : _gapBefore(block)),
          child: render(block),
        ),
      );
    }
    return out;
  }

  double _gapBefore(IrBlock b) => switch (b) {
    IrBlock_Heading() => 22,
    IrBlock_Divider() => 19,
    IrBlock_Code() || IrBlock_Quote() || IrBlock_Table() => 13,
    _ => 10,
  };

  Widget render(IrBlock block) => switch (block) {
    IrBlock_Paragraph(:final spans) => Text.rich(
      TextSpan(children: [for (final s in spans) span(s)]),
      style: style.body,
    ),
    IrBlock_Heading(:final level, :final spans) => Text.rich(
      TextSpan(
        children: [for (final s in spans) span(s, base: _heading(level))],
      ),
      style: _heading(level),
    ),
    IrBlock_Quote(:final children) => _quote(children),
    IrBlock_List(:final ordered, :final start, :final items) => _list(
      ordered: ordered,
      start: start,
      items: items,
    ),
    IrBlock_Code(:final language, :final text) => _code(language, text),
    IrBlock_Divider() => Container(height: 1, color: style.hairline),
    IrBlock_Image(:final path, :final widthPercent, :final isExternal) =>
      _image(path: path, widthPercent: widthPercent, isExternal: isExternal),
    IrBlock_Media(:final kind, :final filename, :final coverPath) => _media(
      kind: kind,
      filename: filename,
      coverPath: coverPath,
    ),
    IrBlock_Table(:final rows) => _table(rows),
  };

  TextStyle _heading(int level) {
    final scale = switch (level) {
      1 => 1.7,
      2 => 1.45,
      3 => 1.25,
      4 => 1.1,
      _ => 1.0,
    };
    return style.bodyStrong.copyWith(fontSize: 16 * scale, height: 1.3);
  }

  TextSpan span(IrSpan s, {TextStyle? base}) {
    final root = base ?? style.body;
    if (s.isPlain) return TextSpan(text: s.text, style: root);

    var out = s.code
        ? style.mono.copyWith(
            fontSize: root.fontSize! * 0.88,
            backgroundColor: style.codeSurface,
          )
        : root;

    if (s.bold) {
      out = style.bodyStrong.copyWith(
        fontSize: out.fontSize,
        height: out.height,
        color: out.color,
        fontFamily: out.fontFamily,
        fontFamilyFallback: out.fontFamilyFallback,
        backgroundColor: out.backgroundColor,
      );
    }
    if (s.italic) out = out.copyWith(fontStyle: FontStyle.italic);

    final decorations = <TextDecoration>[
      if (s.strike) TextDecoration.lineThrough,
      if (s.underline || s.href != null || s.diaryLinkId != null)
        TextDecoration.underline,
    ];
    if (decorations.isNotEmpty) {
      out = out.copyWith(
        decoration: TextDecoration.combine(decorations),
        decorationColor: s.href != null || s.diaryLinkId != null
            ? style.accent
            : null,
      );
    }
    if (s.href != null || s.diaryLinkId != null) {
      out = out.copyWith(color: style.accent);
    }
    return TextSpan(text: s.text, style: out);
  }

  Widget _quote(List<IrBlock> children) => Container(
    padding: const EdgeInsets.only(left: 16),
    decoration: BoxDecoration(
      border: Border(left: BorderSide(color: style.outline, width: 3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultTextStyle(
          style: style.body.copyWith(color: style.muted),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: blocks(children),
          ),
        ),
      ],
    ),
  );

  Widget _list({
    required bool ordered,
    required int start,
    required List<IrListItem> items,
  }) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final checked = item.checked;
      final Widget marker;
      if (checked != null) {
        marker = Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(
            checked ? LucideIcons.squareCheck : LucideIcons.square,
            size: 16,
            color: checked ? style.accent : style.outline,
          ),
        );
      } else if (ordered) {
        marker = Text('${start + i}.', style: style.body);
      } else {
        marker = Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: style.text,
              shape: BoxShape.circle,
            ),
          ),
        );
      }
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Align(alignment: Alignment.topLeft, child: marker),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: blocks(item.children),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _code(String? language, String text) {
    final resolved = resolveCodeLanguage(language);
    final base = style.mono.copyWith(color: style.text);
    TextSpan content = TextSpan(text: text, style: base);
    if (resolved != null) {
      final renderer = TextSpanRenderer(base, style.codeTheme);
      _highlighter.highlight(code: text, language: resolved).render(renderer);
      content = renderer.span ?? content;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: style.codeSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (resolved != null || (language ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(resolved ?? language!, style: style.meta),
            ),
          Text.rich(content, softWrap: true),
        ],
      ),
    );
  }

  Widget _image({
    required String path,
    required int? widthPercent,
    required bool isExternal,
  }) {
    final decoded = images[path];
    if (decoded == null) {
      return _placeholderBox(
        icon: isExternal ? LucideIcons.link : LucideIcons.imageOff,
        label: isExternal ? path : null,
      );
    }
    final width = style.contentWidth * ((widthPercent ?? 100) / 100);
    final height = width * decoded.height / decoded.width;
    return Align(
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: height,
          child: RawImage(
            image: decoded,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }

  Widget _media({
    required String kind,
    required String filename,
    required String? coverPath,
  }) {
    final cover = coverPath == null ? null : images[coverPath];
    if (kind == 'video' && cover != null) {
      final width = style.contentWidth;
      final height = width * cover.height / cover.width;
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RawImage(
                image: cover,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: style.mediaScrim,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.play,
                  size: 20,
                  color: style.onMedia,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _placeholderBox(
      icon: kind == 'video' ? LucideIcons.video : LucideIcons.audioLines,
      label: filename,
      compact: true,
    );
  }

  Widget _placeholderBox({
    required IconData icon,
    String? label,
    bool compact = false,
  }) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 12 : 24),
    decoration: BoxDecoration(
      color: style.placeholder,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisAlignment: compact
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: style.muted),
        if (label != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: style.meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _table(List<IrRow> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final columns = rows
        .map((r) => r.cells.length)
        .reduce((a, b) => a > b ? a : b);
    return Table(
      border: TableBorder.all(color: style.hairline, width: 1),
      defaultColumnWidth: const FlexColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (final row in rows)
          TableRow(
            decoration: row.cells.any((c) => c.header)
                ? BoxDecoration(color: style.codeSurface)
                : null,
            children: [
              for (var i = 0; i < columns; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: i < row.cells.length
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: blocks(row.cells[i].children),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
      ],
    );
  }
}
