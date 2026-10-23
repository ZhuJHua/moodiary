import 'dart:math';

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import 'floating_bars.dart';
import 'panel_parts.dart';

enum HorizontalRuleVariant { solid, dashed, dotted, double, wavy, text }

class DividerPicker extends StatelessWidget {
  final HorizontalRuleVariant? current;
  final ValueChanged<HorizontalRuleVariant> onPick;

  const DividerPicker({super.key, required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    return FloatingCard(
      padding: const .all(16),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          PopoverHeader(
            title: t.divider,
            value: current == null ? '' : _variantLabel(context, current!),
          ),
          const SizedBox(height: 14),
          Column(
            spacing: 8,
            children: [
              for (var row = 0; row < 3; row++)
                Row(
                  spacing: 8,
                  children: [
                    for (var col = 0; col < 2; col++)
                      Expanded(
                        child: _StyleChoice(
                          variant: HorizontalRuleVariant.values[row * 2 + col],
                          selected:
                              current ==
                              HorizontalRuleVariant.values[row * 2 + col],
                          onPick: onPick,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StyleChoice extends StatelessWidget {
  final HorizontalRuleVariant variant;
  final bool selected;
  final ValueChanged<HorizontalRuleVariant> onPick;

  const _StyleChoice({
    required this.variant,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final label = _variantLabel(context, variant);
    final radius = BorderRadius.circular(theme.radii.md);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: MInkWell(
        onTap: () => onPick(variant),
        borderRadius: radius,
        child: Container(
          height: 64,
          padding: const .symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: panelGroupColor(context),
            borderRadius: radius,
            border: Border.all(
              color: selected ? colors.outline : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: .center,
            crossAxisAlignment: .stretch,
            spacing: 8,
            children: [
              IconTheme.merge(
                data: IconThemeData(color: colors.onSurfaceVariant),
                child: _RulePreview(variant),
              ),
              Text(label, style: theme.typography.labelSmall.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

String _variantLabel(BuildContext context, HorizontalRuleVariant v) {
  final t = context.l10n.editor.toolbar;
  return switch (v) {
    .solid => t.dividerSolid,
    .dashed => t.dividerDashed,
    .dotted => t.dividerDotted,
    .double => t.dividerDouble,
    .wavy => t.dividerWavy,
    .text => t.dividerText,
  };
}

class _RulePreview extends StatelessWidget {
  final HorizontalRuleVariant variant;

  const _RulePreview(this.variant);

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color!;
    if (variant == .text) {
      return SizedBox(
        width: double.infinity,
        child: Row(
          spacing: 3,
          children: [
            Expanded(child: _line(.solid, color)),
            Icon(LucideIcons.type, size: 11, color: color),
            Expanded(child: _line(.solid, color)),
          ],
        ),
      );
    }
    return _line(variant, color);
  }

  static Widget _line(HorizontalRuleVariant variant, Color color) => SizedBox(
    height: 8,
    child: CustomPaint(painter: _RulePainter(variant, color)),
  );
}

class _RulePainter extends CustomPainter {
  final HorizontalRuleVariant variant;
  final Color color;

  _RulePainter(this.variant, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final y = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = .stroke;
    switch (variant) {
      case .solid || .text:
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      case .dashed:
        for (double x = 0; x < size.width; x += 6) {
          canvas.drawLine(
            Offset(x, y),
            Offset(min(x + 3.5, size.width), y),
            paint,
          );
        }
      case .dotted:
        final dot = Paint()..color = color;
        for (double x = 1.5; x < size.width; x += 5) {
          canvas.drawCircle(Offset(x, y), 1.4, dot);
        }
      case .double:
        paint.strokeWidth = 1.2;
        canvas.drawLine(Offset(0, y - 1.8), Offset(size.width, y - 1.8), paint);
        canvas.drawLine(Offset(0, y + 1.8), Offset(size.width, y + 1.8), paint);
      case .wavy:
        paint.strokeWidth = 1.5;
        final path = Path()..moveTo(0, y);
        for (double x = 0; x < size.width; x += 8.5) {
          path
            ..quadraticBezierTo(x + 2.125, y - 2.5, x + 4.25, y)
            ..quadraticBezierTo(x + 6.375, y + 2.5, x + 8.5, y);
        }
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RulePainter old) =>
      old.variant != variant || old.color != color;
}
