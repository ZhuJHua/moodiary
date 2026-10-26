import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

class MoodPeriodHeader extends StatelessWidget {
  final MoodInsightsScope scope;
  final DateTime start;
  final DateTime end;
  final VoidCallback onPickPeriod;
  final ValueChanged<MoodInsightsScope> onChanged;

  const MoodPeriodHeader({
    super.key,
    required this.scope,
    required this.start,
    required this.end,
    required this.onPickPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final last = moodDayOffset(end, -1);
    final sameYear = start.year == last.year;
    final sameMonth = sameYear && start.month == last.month;
    final eyebrow = switch (scope) {
      .month => context.l10n.insights.yearTitle(year: start.year),
      .year => '',
      .week when sameMonth => DateFormat.yMMM(locale).format(start),
      .week when sameYear => context.l10n.insights.yearTitle(year: start.year),
      .week => context.l10n.insights.yearRange(
        start: start.year,
        end: last.year,
      ),
    };
    final label = switch (scope) {
      .month => DateFormat.MMM(locale).format(start),
      .year => context.l10n.insights.yearTitle(year: start.year),
      .week when sameMonth => context.l10n.insights.weekDays(
        start: start.day,
        end: last.day,
      ),
      .week => context.l10n.insights.weekTitle(
        start: DateFormat.MMMd(locale).format(start),
        end: DateFormat.MMMd(locale).format(last),
      ),
    };
    final typography = context.theme.typography;
    final options = [
      MSegmentOption(
        value: MoodInsightsScope.week,
        label: context.l10n.insights.week,
      ),
      MSegmentOption(
        value: MoodInsightsScope.month,
        label: context.l10n.insights.month,
      ),
      MSegmentOption(
        value: MoodInsightsScope.year,
        label: context.l10n.insights.year,
      ),
    ];
    // Keep the compact size at normal scale, and let enlarged labels breathe.
    final enlarged = MediaQuery.textScalerOf(context).scale(14) > 14;
    final text = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    var segmentWidth = 0.0;
    var segmentHeight = 0.0;
    for (final option in options) {
      text.text = TextSpan(
        text: option.label,
        style: typography.labelLarge.onSurface,
      );
      text.layout();
      segmentWidth = math.max(segmentWidth, text.width);
      segmentHeight = math.max(segmentHeight, text.height);
    }
    text.dispose();
    return Padding(
      padding: const .fromLTRB(4, 4, 4, 12),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          alignment: .spaceBetween,
          crossAxisAlignment: .end,
          spacing: 8,
          runSpacing: 8,
          children: [
            MInkWell(
              key: const ValueKey('insights-period-picker'),
              borderRadius: .circular(12),
              onTap: onPickPeriod,
              child: Padding(
                padding: const .all(4),
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    // A blank line preserves the year header's label position.
                    Text(
                      eyebrow,
                      key: const ValueKey('insights-period-eyebrow'),
                      style: typography.labelMedium.onSurfaceVariant,
                    ),
                    Row(
                      mainAxisSize: .min,
                      spacing: 4,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            key: const ValueKey('insights-period-label'),
                            style: typography.headlineSmall.emphasized.onSurface
                                .copyWith(
                                  fontSize: 24,
                                  fontFeatures: const [.tabularFigures()],
                                ),
                          ),
                        ),
                        const Icon(LucideIcons.chevronDown, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const .only(bottom: 4),
              child: SizedBox(
                width: math.min(
                  constraints.maxWidth,
                  enlarged ? math.max(132, segmentWidth * 3 + 28) : 132,
                ),
                child: MSegmentedControl<MoodInsightsScope>(
                  height: math.max(32, segmentHeight + 8),
                  selected: scope,
                  onChanged: onChanged,
                  options: options,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
