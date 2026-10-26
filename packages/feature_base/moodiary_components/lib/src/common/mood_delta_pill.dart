import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

class MoodDeltaPill extends StatelessWidget {
  final double delta;
  const MoodDeltaPill({super.key, required this.delta});

  @override
  Widget build(BuildContext context) => Container(
    padding: const .symmetric(horizontal: 10, vertical: 4),
    decoration: ShapeDecoration(
      color: context.theme.colors.secondaryContainer,
      shape: const StadiumBorder(),
    ),
    child: Row(
      mainAxisSize: .min,
      spacing: 4,
      children: [
        Icon(
          delta < 0 ? LucideIcons.trendingDown : LucideIcons.trendingUp,
          size: 14,
          color: context.theme.colors.onSecondaryContainer,
        ),
        Text(
          context.l10n.insights.signedDelta(
            sign: delta < 0 ? '−' : '+',
            value: delta.abs().toStringAsFixed(1),
          ),
          style: context
              .theme
              .typography
              .labelMedium
              .emphasized
              .onSecondaryContainer
              .copyWith(fontFeatures: const [.tabularFigures()]),
        ),
      ],
    ),
  );
}
