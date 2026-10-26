import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../widget/diary_entry_tile.dart';
import '../widget/today_glyph.dart';
import 'mood_calendar.dart';
import 'mood_patterns.dart';
import 'mood_period_header.dart';
import 'mood_period_picker.dart';

class MoodInsightsPage extends ConsumerStatefulWidget {
  const MoodInsightsPage({super.key});

  @override
  ConsumerState<MoodInsightsPage> createState() => _MoodInsightsPageState();
}

class _MoodInsightsPageState extends ConsumerState<MoodInsightsPage>
    with RouteAware {
  MoodInsightsScope _scope = .month;
  DateTime _anchor = moodDayKey(DateTime.now());
  DateTime? _selected;
  late final _repository = getIt<MoodInsightsRepository>();
  late Future<_InsightsData> _future;
  StreamSubscription<DiaryEvent>? _subscription;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _subscription = getIt<DiaryRepository>().diaryEvents.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), _refresh);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) moodiaryRouteObserver.subscribe(this, route);
  }

  @override
  void didPopNext() => _refresh();

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    moodiaryRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<_InsightsData> _load() async {
    final bounds = moodPeriodBounds(_anchor, _scope);
    final previous = moodPeriodBounds(moodDayOffset(bounds.start, -1), _scope);
    final patternStart = _scope == .month
        ? moodDayOffset(bounds.end, -90)
        : bounds.start;
    final start = patternStart.isBefore(previous.start)
        ? patternStart
        : previous.start;
    try {
      final rows = await _repository.entries(start, bounds.end);
      List<MoodInsightEntry> between(DateTime from, DateTime to) => rows
          .where(
            (e) =>
                !moodDayKey(e.time).isBefore(from) &&
                moodDayKey(e.time).isBefore(to),
          )
          .toList();
      final periodRows = between(bounds.start, bounds.end);
      return _InsightsData(
        rows: periodRows,
        summary: summarizeMood(periodRows),
        previous: summarizeMood(between(previous.start, previous.end)),
        weekdays: moodWeekdayAverages(
          rows,
          start: patternStart,
          end: bounds.end,
        ),
      );
    } catch (e, s) {
      logger.e('Mood insights load failed', error: e, stackTrace: s);
      rethrow;
    }
  }

  void _jump(DateTime anchor, {MoodInsightsScope? scope}) {
    final targetScope = scope ?? _scope;
    final today = moodDayKey(DateTime.now());
    final current = moodPeriodBounds(today, targetScope).start;
    if (moodPeriodBounds(anchor, targetScope).start.isAfter(current)) return;
    setState(() {
      _scope = targetScope;
      _anchor = anchor;
      _selected = null;
      _future = _load();
    });
  }

  void _changeScope(MoodInsightsScope scope) => _jump(_anchor, scope: scope);

  void _move(int direction) {
    final start = moodPeriodBounds(_anchor, _scope).start;
    _jump(switch (_scope) {
      .week => moodDayOffset(start, direction * 7),
      .month => DateTime(start.year, start.month + direction),
      .year => DateTime(start.year + direction),
    });
  }

  Future<void> _pickPeriod() async {
    final date = await MSheet.show<DateTime>(
      context,
      builder: (_) => MoodPeriodPicker(
        scope: _scope,
        anchor: _anchor,
        repository: _repository,
      ),
    );
    if (mounted && date != null) _jump(date);
  }

  @override
  Widget build(BuildContext context) {
    final bounds = moodPeriodBounds(_anchor, _scope);
    final today = moodDayKey(DateTime.now());
    final containsToday =
        !today.isBefore(bounds.start) && today.isBefore(bounds.end);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.insights.title),
        actions: [
          if (!containsToday)
            IconButton(
              tooltip: context.l10n.diary.calendarBackToToday,
              icon: TodayGlyph(day: today.day),
              onPressed: () => _jump(today),
            ),
        ],
      ),
      body: GestureDetector(
        behavior: .opaque,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() > 300) _move(velocity > 0 ? -1 : 1);
        },
        child: ListView(
          padding: .fromLTRB(
            12,
            4,
            12,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            MoodPeriodHeader(
              scope: _scope,
              start: bounds.start,
              end: bounds.end,
              onPickPeriod: _pickPeriod,
              onChanged: _changeScope,
            ),
            FutureBuilder<_InsightsData>(
              future: _future,
              builder: (context, snapshot) {
                final loading = snapshot.connectionState != .done;
                if (!loading && snapshot.hasError) {
                  return _Block(
                    child: Column(
                      children: [
                        Text(context.l10n.insights.loadError),
                        TextButton(
                          onPressed: _refresh,
                          child: Text(context.l10n.insights.retry),
                        ),
                      ],
                    ),
                  );
                }
                final data = loading
                    ? _InsightsData.placeholder(bounds.start, bounds.end)
                    : snapshot.requireData;
                if (data.summary.average == null) {
                  return _Block(
                    child: Padding(
                      padding: const .symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          context.l10n.insights.empty,
                          style: context
                              .theme
                              .typography
                              .bodyMedium
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                final tags = moodTagDeltas(data.rows);
                return MSkeleton(
                  enabled: loading,
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      _Block(
                        child: _Summary(data: data, scope: _scope),
                      ),
                      if (_scope != .week)
                        _Block(
                          title: _scope == .month
                              ? context.l10n.insights.calendar
                              : context.l10n.insights.yearPixels,
                          child: Column(
                            children: [
                              MoodCalendar(
                                scope: _scope,
                                start: bounds.start,
                                days: data.summary.days,
                                selected: _selected,
                                onMonthSelected: (month) =>
                                    _jump(month, scope: .month),
                                onSelected: (day) => setState(
                                  () =>
                                      _selected = day == _selected ? null : day,
                                ),
                              ),
                              if (_selected != null) _dayFooter(data),
                              const SizedBox(height: 8),
                              const MoodInsightsLegend(),
                            ],
                          ),
                        ),
                      _Block(
                        title: _scope == .year
                            ? context.l10n.insights.monthlyTrend
                            : context.l10n.insights.trend,
                        child: _trend(data, bounds.start, bounds.end),
                      ),
                      if (_scope == .week)
                        _Block(
                          title: context.l10n.insights.weekDiaries,
                          child: _WeekEntries(days: data.summary.days),
                        ),
                      if (_scope != .week) ...[
                        _Block(
                          title: context.l10n.insights.distribution,
                          child: MoodDistribution(
                            counts: data.summary.distribution,
                          ),
                        ),
                        _Block(
                          title: context.l10n.insights.weekdayPattern,
                          child: MoodWeekdayPattern(averages: data.weekdays),
                        ),
                        if (tags.isNotEmpty)
                          _Block(
                            title: context.l10n.insights.tags,
                            child: MoodTags(deltas: tags),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _trend(_InsightsData data, DateTime start, DateTime end) {
    final List<DateTime> dates;
    final List<double?> values;
    final List<(int, String)> labels;
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (_scope == .year) {
      dates = [for (var m = 1; m <= 12; m++) DateTime(start.year, m)];
      final averages = moodMonthAverages(data.rows);
      values = [for (final date in dates) averages[date]];
      labels = [
        for (final i in [0, 3, 6, 9])
          (i, DateFormat.MMM(locale).format(dates[i])),
      ];
    } else {
      dates = [
        for (
          var date = start;
          date.isBefore(end);
          date = moodDayOffset(date, 1)
        )
          date,
      ];
      values = [for (final date in dates) data.summary.days[date]?.average];
      labels = _scope == .week
          ? [
              for (var i = 0; i < 7; i++)
                (i, TimeFormat.weekdayNarrow(dates[i])),
            ]
          : [
              for (final i in {0, 7, 14, 21, dates.length - 1}) (i, '${i + 1}'),
            ];
    }
    return MLineChart(
      values: values,
      connectGaps: true,
      yMin: 1,
      yMax: 5,
      baseline: 3,
      yLabelBuilder: (tick) =>
          MoodGlyph(mood: DiaryMood.fromScore(tick), size: 14),
      xLabels: labels,
      pointColor: (_, value) => moodLevel(value)!.colorOf(context),
      semanticsLabel: _scope == .year
          ? context.l10n.insights.monthlyTrend
          : context.l10n.insights.trend,
      tooltipBuilder: (index) {
        final date = dates[index];
        return context.l10n.insights.dayTooltip(
          date: _scope == .year
              ? DateFormat.yMMMM(locale).format(date)
              : TimeFormat.monthDay(date),
          level:
              moodLevel(values[index])?.label(context) ??
              context.l10n.insights.unrecorded,
        );
      },
    );
  }

  Widget _dayFooter(_InsightsData data) {
    final day = _selected!;
    final info = data.summary.days[day];
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.insights.dayDetail(
              date: TimeFormat.monthDay(day),
              level:
                  info?.level?.label(context) ??
                  context.l10n.insights.unrecorded,
            ),
            style: context.theme.typography.labelMedium.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: info == null ? null : () => _showDay(day),
          child: Text(context.l10n.insights.view),
        ),
      ],
    );
  }

  Future<void> _showDay(DateTime day) async {
    Future<List<Diary>> load() async {
      try {
        return await getIt<DiaryRepository>().getDiariesByDateRange(
          day,
          moodDayOffset(day, 1).subtract(const Duration(microseconds: 1)),
        );
      } catch (e, s) {
        logger.e('Mood day diaries load failed', error: e, stackTrace: s);
        rethrow;
      }
    }

    final future = load();
    await MSheet.show<void>(
      context,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height * .75 -
              48 -
              MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: FutureBuilder<List<Diary>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const .all(14),
                child: Center(
                  heightFactor: 1,
                  child: Text(context.l10n.insights.loadError),
                ),
              );
            }
            final loading = snapshot.connectionState != .done;
            final diaries =
                snapshot.data ??
                [
                  for (var i = 0; i < 2; i++)
                    Diary(
                      id: 'skeleton-$i',
                      title: context.l10n.common.untitled,
                      content: '',
                      contentText: context.l10n.common.untitled,
                      time: day,
                      lastModified: day,
                      show: true,
                      imageName: const [],
                      audioName: const [],
                      videoName: const [],
                      tags: const [],
                      type: DiaryType.richText.value,
                    ),
                ];
            return MSkeleton(
              enabled: loading,
              child: ListView(
                shrinkWrap: true,
                primary: false,
                physics: const ClampingScrollPhysics(),
                padding: const .all(14),
                children: [
                  Text(
                    TimeFormat.longDate(day),
                    style: context.theme.typography.titleMedium.onSurface,
                  ),
                  const SizedBox(height: 12),
                  for (final diary in diaries) DiaryEntryTile(diary: diary),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InsightsData {
  final List<MoodInsightEntry> rows;
  final MoodInsightsSummary summary;
  final MoodInsightsSummary previous;
  final List<double?> weekdays;
  const _InsightsData({
    required this.rows,
    required this.summary,
    required this.previous,
    required this.weekdays,
  });

  factory _InsightsData.placeholder(DateTime start, DateTime end) {
    const scores = [4, 3, 5, 2, 4, 1, 3];
    final rows = <MoodInsightEntry>[
      for (var i = 0; moodDayOffset(start, i).isBefore(end); i++)
        if (i % 4 != 3)
          MoodInsightEntry(
            id: 'skeleton-$i',
            time: moodDayOffset(start, i),
            mood: DiaryMood.fromScore(scores[i % scores.length]),
            title: l10n.common.untitled,
            preview: l10n.common.untitled,
            tags: [l10n.insights.week, if (i.isEven) l10n.insights.month],
          ),
    ];
    final summary = summarizeMood(rows);
    return _InsightsData(
      rows: rows,
      summary: summary,
      previous: summary,
      weekdays: moodWeekdayAverages(rows, start: start, end: end),
    );
  }
}

class _Block extends StatelessWidget {
  final String? title;
  final Widget child;
  const _Block({this.title, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .only(bottom: 12),
    child: Card.filled(
      color: context.theme.colors.surfaceContainerLow,
      margin: .zero,
      child: Padding(
        padding: const .all(14),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: context.theme.typography.titleSmall.emphasized.onSurface,
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    ),
  );
}

class _Summary extends StatelessWidget {
  final _InsightsData data;
  final MoodInsightsScope scope;
  const _Summary({required this.data, required this.scope});
  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final delta = moodPeriodDelta(summary, data.previous);
    final recorded =
        summary.days.entries.where((e) => e.value.average != null).toList()
          ..sort((a, b) => b.value.average!.compareTo(a.value.average!));
    Widget metric(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: context.theme.typography.titleMedium.emphasized.onSurface
                .copyWith(fontFeatures: const [.tabularFigures()]),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: .center,
            style: context.theme.typography.labelSmall.onSurfaceVariant,
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          spacing: 10,
          children: [
            MoodGlyph(mood: moodLevel(summary.average), size: 40),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    summary.average!.toStringAsFixed(1),
                    style: context
                        .theme
                        .typography
                        .headlineSmall
                        .emphasized
                        .onSurface
                        .copyWith(fontFeatures: const [.tabularFigures()]),
                  ),
                  Text(
                    moodLevel(summary.average)!.label(context),
                    style: context.theme.typography.bodyMedium.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            if (delta != null)
              Skeleton.leaf(child: MoodDeltaPill(delta: delta)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: .start,
          children: [
            metric(
              scope == .week
                  ? context.l10n.insights.recordedWeek(
                      count: summary.recordedDays,
                    )
                  : '${summary.recordedDays}',
              context.l10n.insights.recordedDays,
            ),
            metric('${summary.entryCount}', context.l10n.insights.entries),
            if (scope == .week)
              metric(
                TimeFormat.weekdayShort(recorded.first.key),
                context.l10n.insights.bestDay,
              )
            else
              metric(
                context.l10n.insights.streakDays(
                  count: summary.longestGoodStreak,
                ),
                context.l10n.insights.streak,
              ),
          ],
        ),
      ],
    );
  }
}

class _WeekEntries extends StatelessWidget {
  final Map<DateTime, MoodInsightDay> days;
  const _WeekEntries({required this.days});
  @override
  Widget build(BuildContext context) {
    final dates = days.keys.toList()..sort((a, b) => b.compareTo(a));
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        for (final day in dates) ...[
          Padding(
            padding: const .symmetric(vertical: 8),
            child: Text(
              context.l10n.insights.dayHeader(
                date: TimeFormat.monthDay(day),
                weekday: day == moodDayKey(DateTime.now())
                    ? context.l10n.insights.today
                    : TimeFormat.weekdayShort(day),
              ),
              style: context
                  .theme
                  .typography
                  .labelMedium
                  .emphasized
                  .onSurfaceVariant,
            ),
          ),
          for (final entry
              in (days[day]!.entries.toList()
                ..sort((a, b) => b.time.compareTo(a.time))))
            MInkWell(
              onTap: () => DiaryRoute(diaryId: entry.id).push(context),
              child: Padding(
                padding: const .symmetric(vertical: 10),
                child: Row(
                  spacing: 8,
                  children: [
                    MoodGlyph(mood: entry.mood, size: 18),
                    Text(
                      TimeFormat.clock(entry.time),
                      style: context
                          .theme
                          .typography
                          .labelSmall
                          .onSurfaceVariant
                          .copyWith(fontFeatures: const [.tabularFigures()]),
                    ),
                    Expanded(
                      child: MediaMarkedText(
                        entry.title.trim().isNotEmpty
                            ? entry.title.trim()
                            : entry.preview.trim().isNotEmpty
                            ? entry.preview.trim()
                            : context.l10n.common.untitled,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: context.theme.typography.bodyMedium.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
