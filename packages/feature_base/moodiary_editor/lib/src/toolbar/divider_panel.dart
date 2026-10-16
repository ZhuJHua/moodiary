import 'dart:math';

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

enum HorizontalRuleVariant { solid, dashed, dotted, double, wavy, text }

class DividerStylePanel extends StatelessWidget {
  final HorizontalRuleVariant? current;
  final String? label;
  final ValueChanged<HorizontalRuleVariant> onPick;

  const DividerStylePanel({
    super.key,
    required this.current,
    required this.label,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = max(12.0, MediaQuery.viewPaddingOf(context).bottom);
    return Padding(
      padding: .fromLTRB(12, 12, 12, bottom),
      child: Column(
        spacing: 8,
        children: [
          for (var row = 0; row < 3; row++)
            Expanded(
              child: Row(
                spacing: 8,
                children: [
                  for (var col = 0; col < 2; col++)
                    Expanded(
                      child: _StyleCard(
                        variant: HorizontalRuleVariant.values[row * 2 + col],
                        selected:
                            current ==
                            HorizontalRuleVariant.values[row * 2 + col],
                        label: label,
                        onTap: () =>
                            onPick(HorizontalRuleVariant.values[row * 2 + col]),
                      ),
                    ),
                ],
              ),
            ),
        ],
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

class _StyleCard extends StatelessWidget {
  final HorizontalRuleVariant variant;
  final bool selected;
  final String? label;
  final VoidCallback onTap;

  const _StyleCard({
    required this.variant,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final name = _variantLabel(context, variant);
    final preview = variant == .text
        ? Row(
            spacing: 8,
            children: [
              Expanded(
                child: Container(height: 1, color: colors.outlineVariant),
              ),
              Text(
                (label?.isNotEmpty ?? false)
                    ? label!
                    : context.l10n.editor.toolbar.dividerLabel,
                style: typo.labelMedium.onSurface,
              ),
              Expanded(
                child: Container(height: 1, color: colors.outlineVariant),
              ),
            ],
          )
        : SizedBox(
            height: 8,
            width: double.infinity,
            child: CustomPaint(
              painter: _RulePainter(variant, colors.onSurfaceVariant),
            ),
          );
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: MInkWell(
        onTap: onTap,
        borderRadius: .circular(14),
        child: Container(
          padding: const .symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: .circular(14),
            border: selected
                ? Border.all(color: colors.primary, width: 2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: .center,
            crossAxisAlignment: .start,
            spacing: 10,
            children: [
              preview,
              Text(
                name,
                style: selected
                    ? typo.labelLarge.onSurface
                    : typo.labelLarge.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      ..strokeWidth = 1.5
      ..style = .stroke;
    switch (variant) {
      case .solid || .text:
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      case .dashed:
        for (double x = 0; x < size.width; x += 9) {
          canvas.drawLine(
            Offset(x, y),
            Offset(min(x + 5, size.width), y),
            paint,
          );
        }
      case .dotted:
        final dot = Paint()..color = color;
        for (double x = 1.5; x < size.width; x += 6) {
          canvas.drawCircle(Offset(x, y), 1.5, dot);
        }
      case .double:
        paint.strokeWidth = 1;
        canvas.drawLine(Offset(0, y - 1.5), Offset(size.width, y - 1.5), paint);
        canvas.drawLine(Offset(0, y + 1.5), Offset(size.width, y + 1.5), paint);
      case .wavy:
        final path = Path()..moveTo(0, y);
        for (double x = 0; x < size.width; x += 12) {
          path
            ..quadraticBezierTo(x + 3, y - 3, x + 6, y)
            ..quadraticBezierTo(x + 9, y + 3, x + 12, y);
        }
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RulePainter old) =>
      old.variant != variant || old.color != color;
}
