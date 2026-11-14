part of '../editor.dart';

extension on _RenderEditorViewport {
  ui.Paragraph _chromeText(
    m.Node node,
    String text,
    TextStyle style, {
    double width = 10000,
    bool ellipsis = false,
  }) {
    final cache = _chrome[node] ??= _LruMap(8);
    final key =
        '$text:${style.hashCode}:${_style.textDirection}:$width:$ellipsis';
    return cache.putIfAbsent(
      key,
      () =>
          (ui.ParagraphBuilder(
                  style.getParagraphStyle(
                    textDirection: _style.textDirection,
                    fontSize: style.fontSize,
                    maxLines: ellipsis ? 1 : null,
                    ellipsis: ellipsis ? '…' : null,
                  ),
                )
                ..pushStyle(style.getTextStyle())
                ..addText(text))
              .build()
            ..layout(ui.ParagraphConstraints(width: width)),
    );
  }

  _ListMarkerLayout? _markerLayout(int index, {int? position}) {
    final layout = _layoutBlock(index);
    if (layout is _TableRowLayout && position != null) {
      final found = layout.contentAt(position - _row(index).position);
      if (found == null) return null;
      return _markerFor(
        found.row,
        found.layout,
        _origin(index) + found.textOrigin,
      );
    }
    return _markerFor(_row(index), _layoutBlock(index), _origin(index));
  }

  _ListMarkerLayout? _markerFor(_Row row, _BlockLayout layout, Offset origin) {
    final marker = row.marker;
    if (marker == null) return null;
    if (layout.markerGeneration != layoutGeneration) {
      layout.markerGeneration = layoutGeneration;
      layout.markerLayouts.clear();
    }
    final local = layout.markerLayouts.putIfAbsent(
      row,
      () => _buildMarker(row, layout),
    );
    return _ListMarkerLayout(
      local.bounds.shift(origin),
      local.baseline + origin.dy,
      local.textBaseline + origin.dy,
      local.kind,
      local.paragraph,
    );
  }

  _ListMarkerLayout _buildMarker(_Row row, _BlockLayout layout) {
    _controller.diagnostics.markerLayouts++;
    final marker = row.marker!, baseline = layout.chunks.first.firstBaseline;
    const origin = Offset.zero;
    final style = row.textStyle(_style).copyWith(color: _style.markerColor);
    final shape = _style.bulletGlyphs.indexOf(marker);
    if (shape >= 0) {
      // List markers sit at half the first line's x-height, not half
      // its ascent (which includes leading when line-height grows).
      final em = style.fontSize ?? 17, diameter = em * .35;
      return _ListMarkerLayout(
        Rect.fromLTWH(
          origin.dx - 8 - diameter,
          baseline - em * .26 - diameter / 2,
          diameter,
          diameter,
        ),
        baseline,
        baseline,
        ['disc', 'circle', 'square'][shape % 3],
      );
    }
    final full = _chromeText(row.node, marker, style);
    final scale = math.min(
      1.0,
      math.max(1.0, row.markerGutter - 8) / full.maxIntrinsicWidth,
    );
    final paragraph = scale == 1
        ? full
        : _chromeText(
            row.node,
            marker,
            style.copyWith(fontSize: (style.fontSize ?? 17) * scale),
          );
    final markerBaseline = paragraph.computeLineMetrics().first.baseline;
    final bounds = Rect.fromLTWH(
      origin.dx - 8 - paragraph.maxIntrinsicWidth,
      baseline - markerBaseline,
      paragraph.maxIntrinsicWidth,
      paragraph.height,
    );
    return _ListMarkerLayout(
      bounds,
      bounds.top + markerBaseline,
      baseline,
      'number',
      paragraph,
    );
  }

  Rect? _checkboxFor(_Row row, Offset origin) {
    if (row.taskPosition == null) return null;
    final font = _style.paragraph.fontSize ?? 17;
    return Rect.fromLTWH(
      origin.dx - (_style.taskIndent ?? _style.listIndent),
      origin.dy + font * .275,
      font * 1.2,
      font * 1.2,
    );
  }

  void _paintRowChrome(
    Canvas canvas,
    _Row row,
    _BlockLayout layout,
    Offset origin,
    Offset textOrigin,
  ) {
    final marker = _markerFor(row, layout, textOrigin);
    if (marker != null) {
      final paint = Paint()..color = _style.markerColor;
      switch (marker.kind) {
        case 'disc':
          canvas.drawCircle(
            marker.bounds.center,
            marker.bounds.width / 2,
            paint,
          );
        case 'circle':
          canvas.drawCircle(
            marker.bounds.center,
            marker.bounds.width / 2,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(
                1,
                (_style.forBlock(row.node).fontSize ?? 17) * .06,
              ),
          );
        case 'square':
          canvas.drawRect(marker.bounds, paint);
        default:
          canvas.drawParagraph(marker.paragraph!, marker.bounds.topLeft);
      }
    }
    final checkbox = _checkboxFor(row, origin);
    if (checkbox != null) {
      final shape = RRect.fromRectAndRadius(checkbox, const Radius.circular(6));
      if (row.taskChecked) {
        canvas.drawRRect(shape, Paint()..color = _style.taskFillColor);
        final inset = checkbox.width / 1.2 * .15;
        final unit = (checkbox.width - inset * 2) / 24;
        final path = Path()
          ..moveTo(
            checkbox.left + inset + 20 * unit,
            checkbox.top + inset + 6 * unit,
          )
          ..lineTo(
            checkbox.left + inset + 9 * unit,
            checkbox.top + inset + 17 * unit,
          )
          ..lineTo(
            checkbox.left + inset + 4 * unit,
            checkbox.top + inset + 12 * unit,
          );
        canvas.drawPath(
          path,
          Paint()
            ..color = _style.taskCheckColor
            ..strokeWidth = checkbox.width / 1.2 * .9 / 24 * 3.2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            checkbox.deflate(.75),
            const Radius.circular(5.25),
          ),
          Paint()
            ..color = _style.markerColor
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }
    }
    final language = row.node.attrs['language'];
    if (_codeBlockHeader == null &&
        row.node.type == 'codeBlock' &&
        language is String) {
      final base = _style
          .forBlock(row.node)
          .copyWith(color: _style.markerColor);
      canvas.drawParagraph(
        _chromeText(
          row.node,
          language,
          base.copyWith(fontSize: 12, height: 1.3),
          width: math.max(
            1,
            (layout.width ?? 1) + row.codePadding.horizontal - 24,
          ),
          ellipsis: true,
        ),
        origin + const Offset(12, 6),
      );
    }
  }

  void _paintBlockBackground(
    Canvas canvas,
    _Row row,
    Rect rect, {
    required bool Function(int position) continues,
    required double spacing,
    double? quoteLeft,
  }) {
    if (row.node.type == 'codeBlock') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        Paint()..color = _style.codeBackground,
      );
      if (_style.codeHeaderDivider case final divider?
          when _codeBlockHeader != null) {
        final y = rect.top + row.codeTop - 6;
        canvas.drawLine(
          Offset(rect.left, y),
          Offset(rect.right, y),
          Paint()
            ..color = divider
            ..strokeWidth = .5,
        );
      }
    }
    for (final (x, position) in row.quotes) {
      canvas.drawRect(
        Rect.fromLTWH(
          (quoteLeft ?? rect.left - row.indent) + x,
          rect.top,
          _style.quoteBorderWidth,
          rect.height + (continues(position) ? spacing : 0),
        ),
        Paint()..color = _style.quoteBorderColor,
      );
    }
  }

  void _paintBlockContent(
    Canvas canvas,
    _Row row,
    _BlockLayout layout,
    Offset origin,
    Rect rect,
    int position,
  ) {
    final selection = _controller.state.selection;
    _paintRowChrome(canvas, row, layout, rect.topLeft, origin);
    if (layout.node.type == 'horizontalRule') {
      _paintRule(canvas, row, rect, position);
    } else if (_nodeViews.containsKey(layout.node.type)) {
    } else if (!layout.hasText) {
      final card = RRect.fromRectAndRadius(
        origin & Size(rect.width, layout.height),
        const Radius.circular(8),
      );
      final selected =
          !_readOnly &&
          selection is m.NodeSelection &&
          selection.from == position;
      canvas.drawRRect(card, Paint()..color = _style.opaqueBackground);
      canvas.drawRRect(
        card,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2 : 1
          ..color = selected ? _style.caretColor : _style.opaqueBorder,
      );
      canvas.drawParagraph(
        layout.chunks.first.paragraph!,
        origin +
            Offset(
              12,
              math.max(0, (layout.height - layout.chunks.first.height) / 2),
            ),
      );
    } else {
      if (layout.node.type == 'codeBlock') {
        final card = rect;
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(
            card.left + 12,
            card.top + row.codeTop,
            card.right - 12,
            card.bottom - 12,
          ),
        );
      }
      var y = origin.dy;
      for (final chunk in layout.chunks) {
        if (y + chunk.height >= 0 && y <= size.height) {
          _paintInlineChunk(canvas, chunk, Offset(origin.dx, y), _style);
        }
        y += chunk.height;
      }
      if (layout.node.type == 'codeBlock') canvas.restore();
    }
  }

  void _paintRule(Canvas canvas, _Row row, Rect rect, int position) {
    final variant = row.node.attrs['variant'] as String? ?? 'solid';
    final paint = Paint()
      ..color = _style.ruleColor
      ..strokeWidth = 1;
    final y = rect.center.dy, left = rect.left, right = rect.right;
    void line(double a, double b, [double? atY]) =>
        canvas.drawLine(Offset(a, atY ?? y), Offset(b, atY ?? y), paint);
    switch (variant) {
      case 'dashed':
        for (var x = left; x < right; x += 10) {
          line(x, math.min(right, x + 6));
        }
      case 'dotted':
        for (var x = left + 4.5; x < right; x += 9) {
          canvas.drawCircle(
            Offset(x, y),
            1.2,
            Paint()..color = _style.markerColor.withValues(alpha: .6),
          );
        }
      case 'double':
        line(left, right, y - 1.5);
        line(left, right, y + 1.5);
      case 'wavy':
        paint.color = _style.markerColor;
        canvas.save();
        canvas.clipRect(rect);
        final path = Path()..moveTo(left, y);
        for (var x = left; x < right; x += 12) {
          path
            ..quadraticBezierTo(x + 3, y - 2.5, x + 6, y)
            ..quadraticBezierTo(x + 9, y + 2.5, x + 12, y);
        }
        canvas.drawPath(
          path,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
        canvas.restore();
      case 'text':
        final label = (row.node.attrs['label'] ?? '').toString();
        if (label.isEmpty) {
          line(left, right);
          break;
        }
        final paragraph = _chromeText(
          row.node,
          label,
          _style
              .forBlock(row.node)
              .copyWith(fontSize: 13, color: _style.markerColor, height: 1.4),
        );
        final width = math.min(
          paragraph.maxIntrinsicWidth,
          math.max(0.0, rect.width - 24),
        );
        final start = rect.center.dx - width / 2;
        line(left, math.max(left, start - 12));
        line(math.min(right, start + width + 12), right);
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(start, rect.top, width, rect.height));
        canvas.drawParagraph(
          paragraph,
          Offset(start, y - paragraph.height / 2),
        );
        canvas.restore();
      default:
        line(left, right);
    }
    if (_controller.state.selection case final m.NodeSelection selection
        when selection.from == position) {
      if (_readOnly) return;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()
          ..color = _style.caretColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }
}

class _ListMarkerLayout {
  const _ListMarkerLayout(
    this.bounds,
    this.baseline,
    this.textBaseline,
    this.kind, [
    this.paragraph,
  ]);
  final Rect bounds;
  final double baseline, textBaseline;
  final String kind;
  final ui.Paragraph? paragraph;
}

// Paint inline backgrounds separately from glyph runs: padding and radius
// must neither stretch monospace glyphs nor change the line metrics.
void _prepareInlineChunk(_ParagraphChunk chunk, TiptapEditorStyle style) {
  final paragraph = chunk.paragraph!;
  void background(
    int from,
    int to,
    double horizontal,
    double vertical,
    Color color,
    double ascent,
    double descent,
    double radius,
    bool highlight,
  ) {
    final lines = <int, Rect>{};
    for (final box in paragraph.getBoxesForRange(from, to)) {
      final rect = box.toRect();
      if (rect.isEmpty) continue;
      final at = paragraph.getPositionForOffset(rect.center).offset;
      final line = paragraph.getLineNumberAt(at) ?? 0;
      lines[line] = lines[line]?.expandToInclude(rect) ?? rect;
    }
    final keys = lines.keys.toList()..sort();
    for (final line in keys) {
      final rect = lines[line]!, metric = paragraph.getLineMetricsAt(line)!;
      // Inline backgrounds use half-leading around the font box. Flutter's
      // proportional leading can put the glyph baseline lower; do not move it.
      final lineHeight = style.exactLineHeight
          ? (chunk.base!.fontSize ?? 17) * (chunk.base!.height ?? 1.5)
          : metric.ascent + metric.descent;
      final lineTop = style.exactLineHeight
          ? line * lineHeight
          : metric.baseline - metric.ascent;
      final highlightHeight =
          style.highlightHeight?.call(ascent, descent) ?? ascent + descent;
      final top = highlight
          ? lineTop + (lineHeight - highlightHeight) / 2
          : metric.baseline - ascent - vertical;
      final bounds = Rect.fromLTRB(
        rect.left - (highlight || line == keys.first ? horizontal : 0),
        top,
        rect.right + (highlight || line == keys.last ? horizontal : 0),
        highlight
            ? top + highlightHeight
            : metric.baseline + descent + vertical,
      );
      chunk.inlineBackgrounds.add((
        RRect.fromRectAndRadius(bounds, Radius.circular(radius)),
        color,
      ));
    }
  }

  for (final (from, to, color, ascent, descent) in chunk.highlightBoxes) {
    background(
      from,
      to,
      style.highlightPadding,
      0,
      color,
      ascent,
      descent,
      style.highlightRadius,
      true,
    );
  }
  for (final (from, to, horizontal, vertical, color, ascent, descent)
      in chunk.codeBoxes) {
    background(
      from,
      to,
      horizontal,
      vertical,
      color,
      ascent,
      descent,
      style.inlineCodeRadius,
      false,
    );
  }
  final boxes = chunk.chips.isEmpty
      ? const <ui.TextBox>[]
      : paragraph.getBoxesForPlaceholders();
  for (final (_, chip, index, at) in chunk.chips) {
    final box = boxes[index].toRect();
    final baseline = paragraph
        .getLineMetricsAt(paragraph.getLineNumberAt(at) ?? 0)!
        .baseline;
    final rect = Rect.fromLTWH(
      box.left,
      baseline - chip.computeLineMetrics().first.baseline,
      box.width,
      chip.height,
    );
    chunk.chipRects.add((chip, rect));
  }
}

void _paintInlineChunk(
  Canvas canvas,
  _ParagraphChunk chunk,
  Offset origin,
  TiptapEditorStyle style,
) {
  for (final (bounds, color) in chunk.inlineBackgrounds) {
    canvas.drawRRect(bounds.shift(origin), Paint()..color = color);
  }
  canvas.drawParagraph(chunk.paragraph!, origin);
  for (final (chip, bounds) in chunk.chipRects) {
    final rect = bounds.shift(origin);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(style.referenceRadius)),
      Paint()..color = style.referenceBackground,
    );
    // Keep fractional baseline placement in the transform; SkParagraph snaps
    // a fractional paint offset before positioning its glyphs.
    canvas.save();
    canvas.translate(rect.left + style.referencePadding, rect.top);
    canvas.drawParagraph(chip, Offset.zero);
    canvas.restore();
  }
}
