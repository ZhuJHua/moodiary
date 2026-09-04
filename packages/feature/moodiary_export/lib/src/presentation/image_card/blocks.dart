import 'dart:ui' as ui;

import 'package:moodiary_components/moodiary_components.dart';

import '../../data/export_doc.dart';
import 'card_style.dart';

/// IR 的 9 种块 → widget。
///
/// 与 `MarkdownWriter` / fast_press 的两个 writer 平级：同一份 [IrBlock] 的第四种落地方式。
/// 遇不到的节点在遍历那一步就已经被收进 `ExportDoc.unsupportedNodes` 报给用户了，
/// 所以这里只管画，不做诊断。
class IrBlockRenderer {
  final ImageCardStyle style;

  /// 已经预解码好的图片，键是 IR 里的路径。**离屏渲染树不会跑第二帧**，
  /// 所以这里只接 `ui.Image`，不接 `ImageProvider`。
  final Map<String, ui.Image> images;

  /// 语法高亮引擎（无状态，全局一份）。
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

  /// 块与块之间的间距，照编辑器的 margin 折算（正文 16px 下 .6em ≈ 10）。
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

  // ------------------------------------------------------------------ 行内

  TextStyle _heading(int level) {
    // 编辑器：h1 1.7em / h2 1.45em / h3 1.25em / h4 1.1em / h5·h6 1em，一律 SemiBold。
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

    // 行内代码自带底色与等宽，其余修饰叠在正文上。
    var out = s.code
        ? style.mono.copyWith(
            fontSize: root.fontSize! * 0.88,
            backgroundColor: style.codeSurface,
          )
        : root;

    if (s.bold) {
      // 字重只能整档换：从强调档起手、把其余字段抄过来，不裸改 fontWeight
      // （可变字体下它会被 fontVariations 吃掉）。
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
      // 链接与双链都画成强调色下划线 —— 图片里点不动，但读者要看得出这里原本是个链接。
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

  // -------------------------------------------------------------------- 块

  Widget _quote(List<IrBlock> children) => Container(
    padding: const EdgeInsets.only(left: 16),
    decoration: BoxDecoration(
      border: Border(left: BorderSide(color: style.outline, width: 3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 引用里的正文是次级色，其余排版不变。
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
    // 认得出语法才高亮；认不出就整块用正文色，不猜。
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
          // 长行在图片里没有横滚可言，只能折 —— 宁可折行也不能裁掉。
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
    // 外链图不下载（与其它三种格式同口径），缺图也走同一个占位。
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
                  // 叠在画面上的前景走 onMedia —— 深浅两套主题下它都站得住。
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

  /// 简版网格：等分列宽 + 表头底色。
  ///
  /// **`colspan` / `rowspan` 只按内容画、不做跨格合并** —— Flutter 的 [Table] 没有
  /// 跨格能力，为图片导出自绘一套表格布局不划算。合并单元格的内容仍在，只是各占一格。
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
