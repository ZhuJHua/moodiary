part of '../editor.dart';

extension on _RenderEditorViewport {
  ui.Paragraph _chromeText(m.Node node, String text, TextStyle style) {
    final cache = _chrome[node] ??= {};
    final key = '$text:${style.hashCode}:${_style.textDirection}';
    return cache.putIfAbsent(
      key,
      () =>
          (ui.ParagraphBuilder(
                  style.getParagraphStyle(
                    textDirection: _style.textDirection,
                    fontSize: style.fontSize,
                  ),
                )
                ..pushStyle(style.getTextStyle())
                ..addText(text))
              .build()
            ..layout(const ui.ParagraphConstraints(width: 10000)),
    );
  }

  _ListMarkerLayout? _markerLayout(int index) {
    final row = _row(index), marker = row.marker;
    if (marker == null) return null;
    final layout = _layoutBlock(index), origin = _origin(index);
    final line = layout.chunks.first.paragraph!.computeLineMetrics().first;
    final baseline = origin.dy + line.baseline;
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
    final paragraph = _chromeText(row.node, marker, style);
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

  void _paintRowChrome(Canvas canvas, int index) {
    final row = _row(index), origin = _rowOrigin(index);
    final base = _style.forBlock(row.node).copyWith(color: _style.markerColor);
    final marker = _markerLayout(index);
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
              ..strokeWidth = math.max(1, (base.fontSize ?? 17) * .06),
          );
        case 'square':
          canvas.drawRect(marker.bounds, paint);
        default:
          canvas.drawParagraph(marker.paragraph!, marker.bounds.topLeft);
      }
    }
    final checkbox = taskCheckboxRect(row.position);
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
      canvas.drawParagraph(
        _chromeText(
          row.node,
          language,
          base.copyWith(fontSize: 12, height: 1.3),
        ),
        origin + const Offset(12, 6),
      );
    }
  }

  void _paintRule(Canvas canvas, int index) {
    final row = _row(index), rect = rowRect(row.position);
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
        when selection.from == row.position) {
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
void _paintInlineChunk(
  Canvas canvas,
  _ParagraphChunk chunk,
  Offset origin,
  TiptapEditorStyle style,
) {
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
      ).shift(origin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds, Radius.circular(radius)),
        Paint()..color = color,
      );
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
  canvas.drawParagraph(paragraph, origin);
  final boxes = paragraph.getBoxesForPlaceholders();
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
    ).shift(origin);
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
