import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class MoodInsightsCard extends StatelessWidget {
  final MoodInsightsCardData data;
  const MoodInsightsCard({super.key, required this.data});

  factory MoodInsightsCard.placeholder() {
    final today = moodDayKey(DateTime.now());
    final rows = [
      for (var i = -6; i <= 0; i++)
        MoodInsightEntry(
          id: 'skeleton-$i',
          time: moodDayOffset(today, i),
          mood: .good,
        ),
    ];
    final days = moodDays(rows);
    return MoodInsightsCard(
      data: MoodInsightsCardData(
        month: summarizeMood(rows),
        delta: .5,
        lastSevenDays: [
          for (var i = -6; i <= 0; i++) days[moodDayOffset(today, i)],
        ],
        hasRecordedMood: true,
        today: today,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography;
    return Card.filled(
      color: context.theme.colors.surfaceContainerLow,
      margin: .zero,
      clipBehavior: .antiAlias,
      child: MInkWell(
        onTap: () => const MoodInsightsRoute().push(context),
        child: Padding(
          padding: const .all(14),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Row(
                crossAxisAlignment: .start,
                spacing: 8,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: .baseline,
                      textBaseline: .alphabetic,
                      spacing: 6,
                      children: [
                        Text(
                          data.month.average?.toStringAsFixed(1) ?? '–',
                          style: typo.headlineSmall.emphasized.onSurface
                              .copyWith(
                                fontFeatures: const [.tabularFigures()],
                              ),
                        ),
                        Flexible(
                          child: Text(
                            context.l10n.insights.monthMood(
                              level:
                                  moodLevel(data.month.average)
                                      ?.label(context) ??
                                  context.l10n.insights.unrecorded,
                            ),
                            style: typo.bodyMedium.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (data.delta != null)
                    Skeleton.leaf(child: MoodDeltaPill(delta: data.delta!)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Column(
                        spacing: 6,
                        children: [
                          MoodGlyph(
                            mood: data.lastSevenDays[i]?.level,
                            size: 30,
                          ),
                          Text(
                            i == 6
                                ? context.l10n.insights.today
                                : TimeFormat.weekdayNarrow(
                                    moodDayOffset(data.today, i - 6),
                                  ),
                            style: typo.labelSmall.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.insights.title,
                      style: typo.labelMedium.onSurfaceVariant,
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: context.theme.colors.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
