import 'package:flutter/foundation.dart' show internal;
import 'package:intl/intl.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

@internal
class MoodPeriodPicker extends StatefulWidget {
  final MoodInsightsScope scope;
  final DateTime anchor;
  final MoodInsightsRepository repository;

  const MoodPeriodPicker({
    super.key,
    required this.scope,
    required this.anchor,
    required this.repository,
  });

  @override
  State<MoodPeriodPicker> createState() => _MoodPeriodPickerState();
}

class _MoodPeriodPickerState extends State<MoodPeriodPicker> {
  late DateTime _month = DateTime(widget.anchor.year, widget.anchor.month);
  late final _today = moodDayKey(DateTime.now());
  DateTime? _earliest;
  late Future<Map<DateTime, double?>> _future = _load();

  Future<Map<DateTime, double?>> _load() async {
    try {
      if (_earliest == null) {
        final first = moodDayKey(
          await widget.repository.earliestEntry() ?? _today,
        );
        _earliest = first.isAfter(_today) ? _today : first;
      }
      if (widget.scope == .week) return const {};
      final start = widget.scope == .year
          ? DateTime(_earliest!.year)
          : DateTime(_month.year);
      final end = DateTime(
        (widget.scope == .year ? _today.year : _month.year) + 1,
      );
      final rows = await widget.repository.entries(start, end);
      return widget.scope == .year
          ? moodYearAverages(rows)
          : moodMonthAverages(rows);
    } catch (e, s) {
      logger.e('Mood period picker load failed', error: e, stackTrace: s);
      rethrow;
    }
  }

  void _move(int direction) => setState(() {
    _month = widget.scope == .month
        ? DateTime(_month.year + direction, _month.month)
        : DateTime(_month.year, _month.month + direction);
    if (widget.scope == .month) _future = _load();
  });

  @override
  Widget build(BuildContext context) => MSheetScaffold<DateTime>(
    title: switch (widget.scope) {
      .month => context.l10n.insights.selectMonth,
      .year => context.l10n.insights.selectYear,
      .week => context.l10n.insights.selectWeek,
    },
    icon: LucideIcons.calendarDays,
    child: FutureBuilder<Map<DateTime, double?>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            children: [
              Text(context.l10n.insights.loadError),
              TextButton(
                onPressed: () => setState(() => _future = _load()),
                child: Text(context.l10n.insights.retry),
              ),
            ],
          );
        }
        final ready = snapshot.connectionState == .done;
        final averages = ready ? snapshot.requireData : <DateTime, double?>{};
        return Padding(
          padding: const .only(bottom: 8),
          child: Column(
            mainAxisSize: .min,
            children: [
              if (widget.scope != .year) _navigation(context, ready),
              const SizedBox(height: 8),
              if (widget.scope == .week)
                _weeks(context)
              else
                GridView.count(
                  shrinkWrap: true,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: widget.scope == .month ? 4 : 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 68,
                  children: [
                    if (widget.scope == .month)
                      for (var month = 1; month <= 12; month++)
                        _cell(
                          context,
                          DateTime(_month.year, month),
                          averages,
                          ready,
                        )
                    else
                      for (
                        var year = (_earliest ?? _today).year;
                        year <= _today.year;
                        year++
                      )
                        _cell(context, DateTime(year), averages, ready),
                  ],
                ),
            ],
          ),
        );
      },
    ),
  );

  Widget _navigation(BuildContext context, bool ready) {
    final monthScope = widget.scope == .month;
    final first = _earliest ?? _today;
    final canBack = monthScope
        ? _month.year > first.year
        : _month.isAfter(DateTime(first.year, first.month));
    final canForward = monthScope
        ? _month.year < _today.year
        : _month.isBefore(DateTime(_today.year, _today.month));
    return Row(
      children: [
        IconButton(
          tooltip: context.l10n.insights.previousPeriod,
          onPressed: ready && canBack ? () => _move(-1) : null,
          icon: const Icon(LucideIcons.chevronLeft),
        ),
        Expanded(
          child: Text(
            monthScope
                ? context.l10n.insights.pickerYear(year: _month.year)
                : DateFormat.yMMMM(
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(_month),
            textAlign: .center,
            style: context.theme.typography.titleMedium.onSurface,
          ),
        ),
        IconButton(
          tooltip: context.l10n.insights.nextPeriod,
          onPressed: ready && canForward ? () => _move(1) : null,
          icon: const Icon(LucideIcons.chevronRight),
        ),
      ],
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime date,
    Map<DateTime, double?> averages,
    bool ready,
  ) {
    final selected =
        moodPeriodBounds(widget.anchor, widget.scope).start == date;
    final enabled = ready && !date.isAfter(_today);
    final colors = context.theme.colors;
    final average = averages[date];
    final radius = BorderRadius.circular(12);
    final label = widget.scope == .month
        ? DateFormat.MMM(Localizations.localeOf(context).toLanguageTag())
              .format(date)
        : context.l10n.insights.yearTitle(year: date.year);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      child: Opacity(
        opacity: enabled ? 1 : .38,
        child: MInkWell(
          key: ValueKey('period-${date.year}-${date.month}'),
          borderRadius: radius,
          onTap: enabled ? () => Navigator.of(context).pop(date) : null,
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? colors.primaryContainer
                  : colors.surfaceContainerHigh,
              borderRadius: radius,
              border: selected
                  ? Border.all(color: colors.primary, width: 1.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: .center,
              spacing: 6,
              children: [
                if (average == null)
                  const SizedBox.square(dimension: 18)
                else
                  MoodGlyph(mood: moodLevel(average), size: 18),
                Text(
                  label,
                  style: context.theme.typography.labelLarge
                      .withColor(
                        selected ? colors.onPrimaryContainer : colors.onSurface,
                      )
                      .copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _weeks(BuildContext context) {
    final start = moodPeriodBounds(_month, .week).start;
    final end = DateTime(_month.year, _month.month + 1);
    final selected = moodPeriodBounds(widget.anchor, .week).start;
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
        for (
          var week = start;
          week.isBefore(end);
          week = moodDayOffset(week, 7)
        )
          _week(context, week, selected: week == selected),
      ],
    );
  }

  Widget _week(BuildContext context, DateTime week, {required bool selected}) {
    final enabled = !week.isAfter(_today);
    final colors = context.theme.colors;
    final radius = BorderRadius.circular(12);
    final last = moodDayOffset(week, 6);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final format = week.year == last.year
        ? DateFormat.MMMd(locale)
        : DateFormat.yMMMd(locale);
    void select() => Navigator.of(context).pop(week);
    return Semantics(
      key: ValueKey('week-row-${week.year}-${week.month}-${week.day}'),
      container: true,
      excludeSemantics: true,
      label: context.l10n.insights.weekTitle(
        start: format.format(week),
        end: format.format(last),
      ),
      button: true,
      selected: selected,
      enabled: enabled,
      onTap: enabled ? select : null,
      child: Opacity(
        opacity: enabled ? 1 : .38,
        child: MInkWell(
          enabled: enabled,
          borderRadius: radius,
          onTap: enabled ? select : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? colors.primaryContainer : null,
              borderRadius: radius,
            ),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _day(
                      context,
                      moodDayOffset(week, i),
                      selected: selected,
                      rowEnabled: enabled,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _day(
    BuildContext context,
    DateTime day, {
    required bool selected,
    required bool rowEnabled,
  }) {
    final colors = context.theme.colors;
    return SizedBox(
      key: ValueKey('week-day-${day.year}-${day.month}-${day.day}'),
      height: 44,
      child: Opacity(
        // Entirely future rows are already dimmed as a unit.
        opacity: !rowEnabled
            ? 1
            : day.isAfter(_today)
            ? .38
            : day.month == _month.month
            ? 1
            : .6,
        child: Center(
          child: Text(
            '${day.day}',
            style: context.theme.typography.labelLarge.withColor(
              selected ? colors.onPrimaryContainer : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
