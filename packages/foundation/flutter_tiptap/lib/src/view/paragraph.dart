part of '../editor.dart';

String _inlineText(m.Node node) => node.content
    .map(
      (n) => n.isText
          ? n.text!
          : n.type == 'hardBreak'
          ? '\n'
          : '\ufffc',
    )
    .join();

class _ParagraphChunk {
  _ParagraphChunk(
    this.start,
    this.end, {
    this.paragraph,
    this.width,
    this.style,
  });
  final List<(m.Node, ui.Paragraph, int, int)> chips = [];
  final List<int> paddingOffsets = [];
  final List<(int, int, double, double, Color, double, double)> codeBoxes = [];
  final List<(int, int, Color, double, double)> highlightBoxes = [];
  int paragraphOffset(int local) =>
      local + prefix + paddingOffsets.where((at) => at <= local).length;
  int documentOffset(int paragraph) =>
      (paragraph -
              prefix -
              paddingOffsets.indexed
                  .where((entry) => entry.$2 + prefix + entry.$1 < paragraph)
                  .length)
          .clamp(0, end - start);

  final int start, end;
  ui.Paragraph? paragraph;
  double? width;
  TiptapEditorStyle? style;
  TextStyle? base;
  TextAlign? alignment;
  double indent = 0;
  int get prefix => indent > 0 ? 1 : 0;
  double? exactHeight;
  double get height => exactHeight ?? paragraph?.height ?? 0;
  _ParagraphChunk shift(int delta) =>
      _ParagraphChunk(
          start + delta,
          end + delta,
          paragraph: paragraph,
          width: width,
          style: style,
        )
        ..exactHeight = exactHeight
        ..indent = indent
        ..alignment = alignment
        ..base = base
        ..chips.addAll(chips)
        ..paddingOffsets.addAll(paddingOffsets)
        ..codeBoxes.addAll(codeBoxes)
        ..highlightBoxes.addAll(highlightBoxes);
}

class _BlockLayout {
  _BlockLayout(this.node)
    : text = node.isTextblock ? _inlineText(node) : node.type {
    chunks = node.type == 'codeBlock'
        ? _splitCode(text)
        : node.isTextblock
        ? _split(text, 0, text.length)
        : [_ParagraphChunk(0, text.length)];
  }
  _BlockLayout._(this.node, this.text, this.chunks);
  final m.Node node;
  final String text;
  late final List<_ParagraphChunk> chunks;
  double height = 0;
  double? width;
  TiptapEditorStyle? style;
  TextSpan? highlight;

  static List<_ParagraphChunk> _splitCode(String text) {
    if (text.isEmpty) return [_ParagraphChunk(0, 0)];
    final chunks = <_ParagraphChunk>[];
    var start = 0;
    while (start < text.length) {
      var end = text.length;
      if (text.length - start > 4800) {
        final newline = text.indexOf('\n', start + 4000);
        if (newline >= 0) end = newline + 1;
      }
      chunks.add(_ParagraphChunk(start, end));
      start = end;
    }
    return chunks;
  }

  double get intrinsicWidth => chunks.fold(
    0.0,
    (width, chunk) => math.max(width, chunk.paragraph?.maxIntrinsicWidth ?? 0),
  );

  static List<_ParagraphChunk> _split(String text, int from, int to) {
    if (from == to) return [_ParagraphChunk(from, to)];
    final result = <_ParagraphChunk>[];
    var start = from;
    while (start < to) {
      var end = to - start <= 4800 ? to : math.min(start + 4000, to);
      if (end < to) {
        final lower = start + 2800;
        var found = false;
        for (final pattern in [
          RegExp(r'\n'),
          RegExp(r'[.!?。！？]'),
          RegExp(r'\s'),
        ]) {
          final matches = pattern
              .allMatches(text, lower)
              .takeWhile((m) => m.end <= end)
              .toList();
          if (matches.isNotEmpty) {
            end = matches.last.end;
            found = true;
            break;
          }
        }
        if (!found &&
            end > start &&
            end < text.length &&
            text.codeUnitAt(end) >= 0xdc00 &&
            text.codeUnitAt(end) <= 0xdfff) {
          end--;
        }
        // Keep combining marks and ZWJ sequences within one paragraph chunk.
        var boundary = start;
        for (final cluster
            in text.substring(start, math.min(to, end + 64)).characters) {
          if (boundary + cluster.length > end) break;
          boundary += cluster.length;
        }
        if (boundary > start) end = boundary;
      }
      result.add(_ParagraphChunk(start, end));
      start = end;
    }
    return result;
  }

  _BlockLayout revise(m.Node replacement) {
    if (!node.isTextblock ||
        !replacement.isTextblock ||
        replacement.type != node.type ||
        !mapEquals(node.attrs, replacement.attrs)) {
      return _BlockLayout(replacement);
    }
    if (node.type == 'codeBlock') return _BlockLayout(replacement);
    final next = _inlineText(replacement);
    var prefix = 0, suffix = 0;
    while (prefix < text.length &&
        prefix < next.length &&
        text.codeUnitAt(prefix) == next.codeUnitAt(prefix)) {
      prefix++;
    }
    while (suffix < text.length - prefix &&
        suffix < next.length - prefix &&
        text.codeUnitAt(text.length - suffix - 1) ==
            next.codeUnitAt(next.length - suffix - 1)) {
      suffix++;
    }
    // Mark-only edits can alter paint even when the plain text is identical.
    if (prefix == text.length && prefix == next.length) {
      return _BlockLayout(replacement);
    }
    final first = chunks.indexWhere((c) => c.end >= prefix);
    var last = chunks.lastIndexWhere((c) => c.start <= text.length - suffix);
    final a = first < 0 ? chunks.length - 1 : first;
    last = math.max(a, last);
    final delta = next.length - text.length;
    final result = <_ParagraphChunk>[
      ...chunks.take(a).map((c) => c.shift(0)),
      ..._split(next, chunks[a].start, chunks[last].end + delta),
      ...chunks.skip(last + 1).map((c) => c.shift(delta)),
    ];
    return _BlockLayout._(replacement, next, result);
  }

  bool layout(
    double width,
    TiptapEditorStyle style,
    TiptapDiagnostics diagnostics, {
    TextStyle? baseStyle,
    TextSpan? codeHighlight,
    TextAlign? textAlign,
    double firstLineIndent = 0,
  }) {
    var changed = false;
    final base =
        baseStyle ??
        (node.isTextblock ? style.forBlock(node) : style.paragraph);
    for (final chunk in chunks) {
      if (chunk.paragraph != null &&
          chunk.width == width &&
          identical(chunk.style, style) &&
          chunk.base == base &&
          chunk.alignment == (textAlign ?? style.textAlign) &&
          chunk.indent == (chunk.start == 0 ? firstLineIndent : 0) &&
          identical(highlight, codeHighlight)) {
        continue;
      }
      final paintEnd =
          node.type == 'codeBlock' &&
              chunk.end < text.length &&
              text[chunk.end - 1] == '\n'
          ? chunk.end - 1
          : chunk.end;
      final builder = ui.ParagraphBuilder(
        base.getParagraphStyle(
          fontSize: base.fontSize ?? 17,
          height: base.height ?? 1.5,
          textDirection: style.textDirection,
          textAlign: textAlign ?? style.textAlign,
          locale: base.locale,
        ),
      )..pushStyle(base.getTextStyle());
      chunk.indent = chunk.start == 0 ? firstLineIndent : 0;
      if (chunk.indent > 0) {
        builder.addPlaceholder(
          chunk.indent,
          0,
          ui.PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          baselineOffset: 0,
        );
      }
      if (node.type == 'codeBlock' && codeHighlight != null) {
        var position = 0;
        void add(InlineSpan span, Color? inherited) {
          if (span is! TextSpan) return;
          final color = span.style?.color ?? inherited, text = span.text ?? '';
          final start = math.max(chunk.start, position),
              end = math.min(paintEnd, position + text.length);
          if (end > start) {
            builder.pushStyle(ui.TextStyle(color: color));
            builder.addText(text.substring(start - position, end - position));
            builder.pop();
          }
          position += text.length;
          for (final child in span.children ?? const <InlineSpan>[]) {
            add(child, color);
          }
        }

        add(codeHighlight, base.color);
        if (chunk.end == chunk.start) builder.addText('\u200b');
      } else if (node.isTextblock) {
        chunk.chips.clear();
        chunk.paddingOffsets.clear();
        chunk.codeBoxes.clear();
        chunk.highlightBoxes.clear();
        var local = 0,
            paragraphOffset = chunk.prefix,
            placeholders = chunk.prefix;
        int? codeStart, highlightStart;
        Color? highlightColor;
        double highlightAscent = 0, highlightDescent = 0;
        double codePad = 0, codeVertical = 0;
        Color codeColor = const Color(0x00000000);
        double codeAscent = 0, codeDescent = 0;
        void pad(double width) {
          builder.addPlaceholder(
            width,
            0,
            ui.PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            baselineOffset: 0,
          );
          chunk.paddingOffsets.add(local);
          paragraphOffset++;
          placeholders++;
        }

        void closeCode() {
          if (codeStart == null) return;
          final end = paragraphOffset;
          pad(codePad);
          chunk.codeBoxes.add((
            codeStart!,
            end,
            codePad,
            codeVertical,
            codeColor,
            codeAscent,
            codeDescent,
          ));
          codeStart = null;
        }

        void closeHighlight() {
          if (highlightStart == null) return;
          final end = paragraphOffset;
          pad(style.highlightPadding);
          chunk.highlightBoxes.add((
            highlightStart!,
            end,
            highlightColor!,
            highlightAscent,
            highlightDescent,
          ));
          highlightStart = null;
        }

        for (final inline in node.content.cut(chunk.start, paintEnd)) {
          final inlineStyle = style.forInline(inline, base);
          final isCode =
              inline.marks.any((m) => m.type == 'code') &&
              style.inlineCodePadding != Offset.zero;
          if (!isCode) closeCode();
          final isHighlight =
              inline.marks.any((m) => m.type == 'highlight') &&
              (style.highlightPadding > 0 || style.highlightRadius > 0);
          final color = inlineStyle.backgroundColor;
          if (!isHighlight || color != highlightColor) closeHighlight();
          if (isHighlight && highlightStart == null && color != null) {
            highlightColor = color;
            final metrics = _inlineFontMetrics(
              inlineStyle,
              style.textDirection,
            );
            highlightAscent = metrics.$1;
            highlightDescent = metrics.$2;
            pad(style.highlightPadding);
            highlightStart = paragraphOffset;
          }

          if (isCode && codeStart == null) {
            codePad = (inlineStyle.fontSize ?? 17) * style.inlineCodePadding.dx;
            codeVertical =
                (inlineStyle.fontSize ?? 17) * style.inlineCodePadding.dy;
            codeColor = inlineStyle.backgroundColor ?? const Color(0x00000000);
            final metrics = _inlineFontMetrics(
              inlineStyle,
              style.textDirection,
            );
            codeAscent = metrics.$1;
            codeDescent = metrics.$2;
            pad(codePad);
            codeStart = paragraphOffset;
          }
          builder.pushStyle(inlineStyle.getTextStyle());
          if (isCode || isHighlight) {
            builder.pushStyle(
              ui.TextStyle(
                background: Paint()..color = const Color(0x00000000),
              ),
            );
          }
          if (inline.type == m.referenceNodeType) {
            final label = (inline.attrs['label'] ?? inline.attrs['id'] ?? '')
                .toString();
            final chip =
                (ui.ParagraphBuilder(
                        base
                            .copyWith(height: ui.kTextHeightNone)
                            .getParagraphStyle(
                              textDirection: style.textDirection,
                            ),
                      )
                      ..pushStyle(
                        style
                            .forInline(inline, base)
                            .merge(style.reference)
                            .copyWith(height: ui.kTextHeightNone)
                            .getTextStyle(),
                      )
                      ..addText(label))
                    .build()
                  ..layout(const ui.ParagraphConstraints(width: 100000));
            chunk.chips.add((inline, chip, placeholders++, paragraphOffset));
            builder.addPlaceholder(
              chip.maxIntrinsicWidth + style.referencePadding * 2,
              chip.height,
              ui.PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              baselineOffset: chip.computeLineMetrics().first.baseline,
            );
          } else if (inline.isText && style.textRuns != null) {
            final runs = style.textRuns!(inline.text!, inlineStyle).toList();
            assert(runs.map((run) => run.$1).join() == inline.text);
            for (final (text, runStyle) in runs) {
              builder.pushStyle(runStyle.getTextStyle());
              if (isCode || isHighlight) {
                builder.pushStyle(
                  ui.TextStyle(
                    background: Paint()..color = const Color(0x00000000),
                  ),
                );
              }
              builder.addText(text);
              if (isCode || isHighlight) builder.pop();
              builder.pop();
            }
          } else {
            builder.addText(
              inline.isText
                  ? inline.text!
                  : inline.type == 'hardBreak'
                  ? '\n'
                  : '\ufffc',
            );
          }
          if (isCode || isHighlight) builder.pop();
          builder.pop();
          local += inline.nodeSize;
          paragraphOffset += inline.nodeSize;
        }
        closeCode();
        closeHighlight();
        if (chunk.end == chunk.start) builder.addText('\u200b');
      } else {
        builder.addText(text);
      }
      final paragraph = builder.build()
        ..layout(
          ui.ParagraphConstraints(
            width: node.type == 'codeBlock' && !style.wrapCodeBlocks
                ? 100000000
                : math.max(1, width),
          ),
        );
      chunk.paragraph = paragraph;
      chunk.exactHeight = style.exactLineHeight
          ? paragraph.computeLineMetrics().length *
                (base.fontSize ?? 17) *
                (base.height ?? 1.5)
          : null;
      chunk.width = width;
      chunk.style = style;
      chunk.base = base;
      chunk.alignment = textAlign ?? style.textAlign;
      diagnostics.paragraphLayouts++;
      changed = true;
    }
    highlight = codeHighlight;
    this.width = width;
    this.style = style;
    height = node.isTextblock
        ? chunks.fold<double>(0, (h, c) => h + c.height)
        : node.type == 'horizontalRule'
        ? (style.ruleHeights?[node.attrs['variant'] ?? 'solid'] ??
              math.max(24, style.paragraph.fontSize ?? 17))
        : style.opaqueBlockHeight;
    return changed;
  }

  (int, double) chunkAt(int offset) {
    var y = 0.0;
    for (var i = 0; i < chunks.length; i++) {
      if (offset < chunks[i].end || i == chunks.length - 1) return (i, y);
      y += chunks[i].height;
    }
    return (0, 0);
  }

  _CaretGeometry caretGeometry(int offset, double width, double factor) {
    final (index, y) = chunkAt(offset);
    final chunk = chunks[index], paragraph = chunk.paragraph!;
    final local = (offset - chunk.start).clamp(0, chunk.end - chunk.start);
    final endsInBreak = local > 0 && text[chunk.start + local - 1] == '\n';
    final at = chunk.paragraphOffset(local);
    var line = paragraph.getLineNumberAt(at);
    line ??=
        (paragraph.getLineNumberAt(math.max(0, at - 1)) ?? 0) +
        (endsInBreak ? 1 : 0);
    final metric =
        paragraph.getLineMetricsAt(line) ?? paragraph.computeLineMetrics().last;
    final base = chunk.base!;
    var font = base;
    var sample = ' ';
    // The insertion font follows the preceding grapheme; at a line/paragraph
    // start use the following run, or the block's font on an empty line.
    final probe = endsInBreak ? -1 : (offset > 0 ? offset - 1 : 0);
    if (probe >= 0) {
      var start = 0;
      for (final inline in node.content) {
        final end = start + inline.nodeSize;
        if (probe < end) {
          if (inline.isText) {
            font = style!.forInline(inline, base);
            final (probeIndex, _) = chunkAt(probe);
            final probeChunk = chunks[probeIndex];
            final range = probeChunk.paragraph!
                .getGlyphInfoAt(
                  probeChunk.paragraphOffset(probe - probeChunk.start),
                )
                ?.graphemeClusterCodeUnitRange;
            if (range != null) {
              final from =
                  (probeChunk.start + probeChunk.documentOffset(range.start))
                      .clamp(0, text.length);
              final to =
                  (probeChunk.start + probeChunk.documentOffset(range.end))
                      .clamp(from, text.length);
              sample = text.substring(from, to);
            }
          }
          break;
        }
        start = end;
      }
    }
    final natural = font.copyWith(height: ui.kTextHeightNone);
    final key = (natural, sample);
    if (_caretFonts.length > 256) _caretFonts.clear();
    final (ascent, descent) = _caretFonts.putIfAbsent(key, () {
      final painter = TextPainter(
        text: TextSpan(text: sample, style: natural),
        textDirection: style!.textDirection,
      )..layout();
      final line = painter.computeLineMetrics().first;
      painter.dispose();
      return (line.ascent, line.descent);
    });
    final baseline = y + metric.baseline;
    final top = baseline - ascent, bottom = baseline + descent;
    final extra = (bottom - top) * (factor - 1) / 2;
    final horizontal = caret(offset, width);
    return _CaretGeometry(
      Rect.fromLTRB(
        horizontal.left,
        top - extra,
        horizontal.right,
        bottom + extra,
      ),
      baseline,
      ascent,
      descent,
    );
  }

  Rect caret(int offset, double caretWidth) {
    final (index, y) = chunkAt(offset);
    final chunk = chunks[index], paragraph = chunk.paragraph!;
    final local = (offset - chunk.start).clamp(0, chunk.end - chunk.start);
    final lines = paragraph.computeLineMetrics();
    final lineHeight = lines.isEmpty ? 24.0 : lines.first.height;
    if (local < chunk.end - chunk.start) {
      final boxes = paragraph.getBoxesForRange(
        chunk.paragraphOffset(local),
        chunk.paragraphOffset(local + 1),
        boxHeightStyle: ui.BoxHeightStyle.strut,
      );
      if (boxes.isNotEmpty) {
        final b = boxes.first;
        return Rect.fromLTWH(
          b.direction == TextDirection.rtl ? b.right : b.left,
          y + b.top,
          caretWidth,
          math.max(1, b.bottom - b.top),
        );
      }
    }
    if (local > 0) {
      if (text[chunk.start + local - 1] == '\n') {
        return Rect.fromLTWH(
          0,
          y + paragraph.height - lineHeight,
          caretWidth,
          lineHeight,
        );
      }
      final start = text
          .substring(chunk.start, chunk.start + local)
          .characters
          .last
          .length;
      final boxes = paragraph.getBoxesForRange(
        chunk.paragraphOffset(local - start),
        chunk.paragraphOffset(local),
        boxHeightStyle: ui.BoxHeightStyle.strut,
      );
      if (boxes.isNotEmpty) {
        final b = boxes.last;
        return Rect.fromLTWH(
          b.direction == TextDirection.rtl ? b.left : b.right,
          y + b.top,
          caretWidth,
          math.max(1, b.bottom - b.top),
        );
      }
    }
    return Rect.fromLTWH(chunk.indent, y, caretWidth, lineHeight);
  }

  int position(Offset offset) {
    var y = 0.0;
    for (final chunk in chunks) {
      if (offset.dy < y + chunk.height || identical(chunk, chunks.last)) {
        return (chunk.start +
                chunk.documentOffset(
                  chunk.paragraph!
                      .getPositionForOffset(Offset(offset.dx, offset.dy - y))
                      .offset,
                ))
            .clamp(chunk.start, chunk.end);
      }
      y += chunk.height;
    }
    return text.length;
  }

  List<Rect> boxes(int from, int to) {
    final result = <Rect>[];
    var y = 0.0;
    for (final chunk in chunks) {
      final a = (from - chunk.start).clamp(0, chunk.end - chunk.start),
          b = (to - chunk.start).clamp(0, chunk.end - chunk.start);
      if (b > a) {
        result.addAll(
          chunk.paragraph!
              .getBoxesForRange(
                chunk.paragraphOffset(a),
                chunk.paragraphOffset(b),
                boxHeightStyle: ui.BoxHeightStyle.strut,
              )
              .map((box) => box.toRect().shift(Offset(0, y))),
        );
      }
      y += chunk.height;
    }
    return result;
  }

  TextRange boundary(int offset, {required bool word}) {
    final (index, _) = chunkAt(offset);
    final chunk = chunks[index];
    final position = TextPosition(
      offset: chunk.paragraphOffset(
        (offset - chunk.start).clamp(0, chunk.end - chunk.start),
      ),
    );
    final range = word
        ? chunk.paragraph!.getWordBoundary(position)
        : chunk.paragraph!.getLineBoundary(position);
    return TextRange(
      start: chunk.start + chunk.documentOffset(range.start),
      end: math.min(chunk.end, chunk.start + chunk.documentOffset(range.end)),
    );
  }
}

final _caretFonts = <(TextStyle, String), (double, double)>{};

class _CaretGeometry {
  const _CaretGeometry(this.rect, this.baseline, this.ascent, this.descent);
  final Rect rect;
  final double baseline, ascent, descent;
  _CaretGeometry shift(Offset offset) =>
      _CaretGeometry(rect.shift(offset), baseline + offset.dy, ascent, descent);
}

(double, double) _inlineFontMetrics(TextStyle style, TextDirection direction) {
  final font = style.copyWith(height: ui.kTextHeightNone);
  return _caretFonts.putIfAbsent((font, 'hgj'), () {
    final painter = TextPainter(
      text: TextSpan(text: 'hgj', style: font),
      textDirection: direction,
    )..layout();
    final line = painter.computeLineMetrics().first;
    painter.dispose();
    return (line.ascent, line.descent);
  });
}
