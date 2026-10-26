import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class MoodCalendar extends StatelessWidget {
  final MoodInsightsScope scope;
  final DateTime start;
  final Map<DateTime, MoodInsightDay> days;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime>? onMonthSelected;
  const MoodCalendar({
    super.key,
    required this.scope,
    required this.start,
    required this.days,
    required this.selected,
    required this.onSelected,
    this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) =>
      scope == .year ? _year(context) : _month(context);

  Widget _month(BuildContext context) {
    final leading = start.weekday % 7;
    final count = DateTime(start.year, start.month + 1, 0).day;
    return Column(
      children: [
        const MoodWeekdayHeader(),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          padding: .zero,
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

  Widget _year(BuildContext context) {
    final firstDay = DateTime(start.year);
    final today = moodDayKey(DateTime.now());
    final end = start.year == today.year ? today : DateTime(start.year, 12, 31);
    // Count calendar days in UTC so DST cannot change the number of columns.
    final dayCount = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year)).inDays;
    return MHeatmap(
      key: ValueKey(start.year),
      startDate: firstDay,
      endDate: end,
      weeks: (firstDay.weekday % 7 + dayCount) ~/ 7 + 1,
      colorOf: (day) => days[day]?.level?.colorOf(context),
      emptyCell: .dashed,
      selected: selected,
      onDaySelected: onSelected,
      onMonthSelected: onMonthSelected,
      monthLabel: TimeFormat.monthAbbr,
      semanticsLabel: context.l10n.insights.yearPixels,
    );
  }

  Widget _cell(BuildContext context, DateTime date) {
    final colors = context.theme.colors;
    final today = moodDayKey(DateTime.now());
    final future = date.isAfter(today);
    final info = days[date];
    final level = info?.level;
    final selectedDay = date == selected;
    final radius = BorderRadius.circular(8);
    final description = context.l10n.insights.dayDetail(
      date: TimeFormat.monthDay(date),
      level: level?.label(context) ?? context.l10n.insights.unrecorded,
    );
    return Skeleton.replace(
      replacement: Bone(
        width: double.infinity,
        height: double.infinity,
        borderRadius: radius,
      ),
      child: Semantics(
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
                color: future ? null : level?.colorOf(context),
                borderRadius: radius,
                border: selectedDay
                    ? Border.all(color: colors.onSurface, width: 1.6)
                    : date == today
                    ? Border.all(color: colors.outline, width: 1.2)
                    : null,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    Text(
                      '${date.day}',
                      style: context.theme.typography.labelMedium.onSurface
                          .copyWith(
                            color: future
                                ? colors.outlineVariant
                                : level?.onColorOf(context) ?? colors.outline,
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
      ),
    );
  }
}

class MoodWeekdayHeader extends StatelessWidget {
  const MoodWeekdayHeader({super.key});

  @override
  Widget build(BuildContext context) => Row(
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
  );
}
