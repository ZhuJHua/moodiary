import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class MoodDistribution extends StatelessWidget {
  final Map<DiaryMood, int> counts;
  const MoodDistribution({super.key, required this.counts});
  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (sum, n) => sum + n);
    return Column(
      spacing: 12,
      children: [
        for (final mood in DiaryMood.values.reversed)
          Row(
            spacing: 8,
            children: [
              MoodGlyph(mood: mood, size: 20),
              SizedBox(
                width: 48,
                child: Text(
                  mood.label(context),
                  style: context.theme.typography.bodySmall.onSurface,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: .centerLeft,
                    child: Skeleton.leaf(
                      child: Container(
                        height: 10,
                        width: total == 0
                            ? 0
                            : constraints.maxWidth *
                                  (counts[mood] ?? 0) /
                                  total,
                        decoration: BoxDecoration(
                          color: mood.colorOf(context),
                          borderRadius: .horizontal(right: const .circular(4)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 78,
                child: Text(
                  context.l10n.insights.countPercent(
                    count: counts[mood] ?? 0,
                    percent: total == 0
                        ? '0'
                        : ((counts[mood] ?? 0) * 100 / total)
                              .round()
                              .toString(),
                  ),
                  textAlign: .end,
                  style: context.theme.typography.labelSmall.onSurfaceVariant
                      .copyWith(fontFeatures: const [.tabularFigures()]),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class MoodWeekdayPattern extends StatelessWidget {
  final List<double?> averages;
  const MoodWeekdayPattern({super.key, required this.averages});
  @override
  Widget build(BuildContext context) {
    const height = 88.0;
    final span = averages
        .take(7)
        .whereType<double>()
        .fold<double>(
          1,
          (span, value) => (value - 3).abs() > span ? (value - 3).abs() : span,
        );
    return Row(
      crossAxisAlignment: .start,
      children: [
        SizedBox(
          width: 28,
          height: height,
          child: Align(
            alignment: .centerLeft,
            child: Text(
              '3.0',
              style: context.theme.typography.labelSmall.outline,
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              SizedBox(
                height: height,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: height / 2 - .5,
                      child: Skeleton.leaf(
                        child: Container(
                          height: 1,
                          color: context.theme.colors.outlineVariant,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final value = averages[i];
                                final barHeight = value == null
                                    ? 0.0
                                    : (value - 3).abs() /
                                          span *
                                          (height / 2 - 4);
                                return Semantics(
                                  label:
                                      '${TimeFormat.weekdayShort(DateTime(2026, 10, 18 + i))}: ${value?.toStringAsFixed(1) ?? context.l10n.insights.unrecorded}',
                                  child: Tooltip(
                                    message:
                                        value?.toStringAsFixed(1) ??
                                        context.l10n.insights.unrecorded,
                                    child: SizedBox(
                                      height: height,
                                      child: Stack(
                                        alignment: .topCenter,
                                        children: [
                                          if (value != null)
                                            Positioned(
                                              top: value >= 3
                                                  ? height / 2 - barHeight
                                                  : height / 2,
                                              child: Skeleton.leaf(
                                                child: Container(
                                                  width: 18,
                                                  height: barHeight,
                                                  decoration: BoxDecoration(
                                                    color: moodLevel(value)!
                                                        .colorOf(context),
                                                    borderRadius: .circular(4),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          TimeFormat.weekdayNarrow(DateTime(2026, 10, 18 + i)),
                          style: context
                              .theme
                              .typography
                              .labelSmall
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MoodTags extends StatelessWidget {
  final List<MoodTagDelta> deltas;
  const MoodTags({super.key, required this.deltas});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    spacing: 12,
    children: [
      for (final delta in deltas)
        Row(
          spacing: 8,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                '#${delta.tag}',
                maxLines: 1,
                overflow: .ellipsis,
                style: context.theme.typography.bodySmall.onSurface,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final extent = deltas.fold<double>(
                    1,
                    (max, e) => e.delta.abs() > max ? e.delta.abs() : max,
                  );
                  final half = constraints.maxWidth / 2;
                  return SizedBox(
                    height: 22,
                    child: Stack(
                      children: [
                        Positioned(
                          left: half,
                          top: 0,
                          bottom: 0,
                          child: Skeleton.leaf(
                            child: Container(
                              width: 1,
                              color: context.theme.colors.outlineVariant,
                            ),
                          ),
                        ),
                        Positioned(
                          left: delta.delta < 0
                              ? half - half * delta.delta.abs() / extent
                              : half,
                          top: 6,
                          child: Skeleton.leaf(
                            child: Container(
                              width: half * delta.delta.abs() / extent,
                              height: 10,
                              decoration: BoxDecoration(
                                color:
                                    (delta.delta < 0
                                            ? DiaryMood.bad
                                            : DiaryMood.good)
                                        .colorOf(context),
                                borderRadius: .circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                context.l10n.insights.signedDelta(
                  sign: delta.delta < 0 ? '−' : '+',
                  value: delta.delta.abs().toStringAsFixed(1),
                ),
                textAlign: .end,
                style: context.theme.typography.labelSmall.onSurfaceVariant
                    .copyWith(fontFeatures: const [.tabularFigures()]),
              ),
            ),
          ],
        ),
    ],
  );
}
