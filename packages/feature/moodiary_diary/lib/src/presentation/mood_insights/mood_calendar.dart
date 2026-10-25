import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class MoodCalendar extends StatelessWidget {
  final MoodInsightsScope scope;
  final DateTime start;
  final Map<DateTime, MoodInsightDay> days;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;
  const MoodCalendar({
    super.key,
    required this.scope,
    required this.start,
    required this.days,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) =>
      scope == .year ? _year(context) : _month(context);

  Widget _month(BuildContext context) {
    final leading = start.weekday % 7;
    final count = DateTime(start.year, start.month + 1, 0).day;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    TimeFormat.weekdayNarrow(DateTime(2026, 10, 18 + i)),
                    style: context.theme.typography.labelSmall.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
          ),
          itemCount: ((leading + count + 6) ~/ 7) * 7,
          itemBuilder: (context, index) {
            final day = index - leading + 1;
            if (day < 1 || day > count) return const SizedBox.shrink();
            return _cell(context, DateTime(start.year, start.month, day));
          },
        ),
      ],
    );
  }

  Widget _year(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Nominal 8px cells; shrink on narrow cards while preserving all 31 columns.
      final cell = math.min(8.0, (constraints.maxWidth - 28 - 30) / 31);
      final width = cell * 31 + 30;
      return Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 28),
              SizedBox(
                width: width,
                height: 18,
                child: Stack(
                  children: [
                    for (final day in [1, 10, 20, 31])
                      Positioned(
                        left: ((day - 1) * (cell + 1) - 4).clamp(0, width - 14),
                        child: Text(
                          '$day',
                          style: context.theme.typography.labelSmall.outline,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          for (var month = 1; month <= 12; month++)
            Padding(
              padding: const .only(bottom: 1),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: cell,
                    child: Align(
                      alignment: .centerLeft,
                      child: [1, 4, 7, 10].contains(month)
                          ? Text(
                              DateFormat.MMM(
                                Localizations.localeOf(context).toLanguageTag(),
                              ).format(DateTime(start.year, month)),
                              maxLines: 1,
                              style: context.theme.typography.labelSmall.outline
                                  .copyWith(fontSize: 9),
                            )
                          : null,
                    ),
                  ),
                  Row(
                    spacing: 1,
                    children: [
                      for (var day = 1; day <= 31; day++)
                        SizedBox.square(
                          dimension: cell,
                          child: day > DateTime(start.year, month + 1, 0).day
                              ? null
                              : _cell(
                                  context,
                                  DateTime(start.year, month, day),
                                  pixel: true,
                                ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _cell(BuildContext context, DateTime date, {bool pixel = false}) {
    final colors = context.theme.colors;
    final today = moodDayKey(DateTime.now());
    final future = date.isAfter(today);
    final info = days[date];
    final level = info?.level;
    final selectedDay = date == selected;
    final radius = BorderRadius.circular(pixel ? 1 : 8);
    final description = context.l10n.insights.dayDetail(
      date: TimeFormat.monthDay(date),
      level: level?.label(context) ?? context.l10n.insights.unrecorded,
      count: info?.entries.length ?? 0,
    );
    return Semantics(
      label: description,
      selected: selectedDay,
      button: true,
      child: Tooltip(
        message: description,
        child: MInkWell(
          borderRadius: radius,
          onTap: future ? null : () => onSelected(date),
          child: Container(
            decoration: BoxDecoration(
              color: future
                  ? (pixel
                        ? colors.surfaceContainerHigh.withValues(alpha: .6)
                        : null)
                  : level?.colorOf(context),
              borderRadius: radius,
              border: selectedDay
                  ? Border.all(color: colors.onSurface, width: 1.6)
                  : date == today
                  ? Border.all(color: colors.outline, width: 1.2)
                  : pixel && level == null && !future
                  ? Border.all(color: colors.outlineVariant)
                  : null,
            ),
            child: pixel
                ? null
                : Center(
                    child: Column(
                      mainAxisSize: .min,
                      children: [
                        Text(
                          '${date.day}',
                          style: context.theme.typography.labelMedium.onSurface
                              .copyWith(
                                color: future
                                    ? colors.outlineVariant
                                    : level?.onColorOf(context) ??
                                          colors.outline,
                                fontFeatures: const [.tabularFigures()],
                              ),
                        ),
                        if (info != null && level == null && !future)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const .only(top: 2),
                            decoration: BoxDecoration(
                              color: colors.outline,
                              shape: .circle,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class MoodInsightsLegend extends StatelessWidget {
  const MoodInsightsLegend({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: .center,
    spacing: 10,
    runSpacing: 8,
    children: [
      for (final mood in [...DiaryMood.values, null])
        Row(
          mainAxisSize: .min,
          spacing: 3,
          children: [
            MoodGlyph(mood: mood, size: 14),
            Text(
              mood?.label(context) ?? context.l10n.insights.unrecorded,
              style: context.theme.typography.labelSmall.onSurfaceVariant,
            ),
          ],
        ),
    ],
  );
}
