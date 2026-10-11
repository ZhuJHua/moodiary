import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_diary/src/application/word_cloud_controller.dart';
import 'package:moodiary_diary/src/application/word_cloud_settings.dart';
import 'package:moodiary_diary/src/presentation/wordcloud/word_cloud_canvas.dart';
import 'package:moodiary_diary/src/presentation/wordcloud/word_cloud_layout.dart';
import 'package:moodiary_diary/src/presentation/wordcloud/word_cloud_range_page.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

/// 词云：一屏三个区域 —— **上面选时间范围、中间是词云、下面是播放控制**。
///
/// 范围栏写着实际起止日期与派生出来的张数（点它调整）；
/// 播放控制条里放进度、播放/暂停、快慢，以及「本段 / 累计」这个控制器。
class WordCloudPage extends ConsumerStatefulWidget {
  const WordCloudPage({super.key});

  @override
  ConsumerState<WordCloudPage> createState() => _WordCloudPageState();
}

class _WordCloudPageState extends ConsumerState<WordCloudPage>
    with SingleTickerProviderStateMixin {
  /// 每段的基础时长（1.0 倍速）。一年 12 段 ≈ 10 秒。
  static const Duration _perSegment = Duration(milliseconds: 900);

  /// 可选速度（慢 → 快）。
  static const List<double> _speeds = [0.5, 0.75, 1, 1.5, 2, 3];

  /// 算不算「滑动了一下」。小于这个距离当作点击（词还要能点开）。
  static const double _swipeSlop = 16;

  WordCloudTimeline _timeline = const WordCloudTimeline.preset(
    WordCloudRangePreset.year,
  );
  WordCloudPlayMode _mode = WordCloudPlayMode.perBucket;
  double _speed = 1;
  int _segments = 0;

  /// 最新一份数据：手势切段、记锚点都要用。
  WordCloudData? _data;

  /// 待重新定位的时间点。数据重算（换区间/换单位/改词表）后用它回到同一段时间，
  /// 而不是跳回开头。
  DateTime? _anchor;

  /// 这一次滑动的累计位移。
  Offset _swipe = Offset.zero;

  late final AnimationController _playback;
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    // 动画只由播放按钮启动：进页面、换区间、改词表都不自动播。
    _playback = AnimationController(vsync: this, duration: _perSegment)
      ..addListener(() => _progress.value = _playback.value)
      ..addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _playback.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // 让播放按钮回到「播放」态
    setState(() {});
  }

  Duration _durationFor(int segments) => Duration(
    microseconds: (_perSegment.inMicroseconds * math.max(1, segments) / _speed)
        .round(),
  );

  /// 段数变了就重设总时长。
  void _ensureDuration(int segments) {
    if (segments == _segments) return;
    _segments = segments;
    _playback.duration = _durationFor(segments);
  }

  bool get _playing => _playback.isAnimating;

  /// 当前显示第几段（吸附口径，和标签一致）。
  int get _index => _data?.nearestWindowAt(_playback.value) ?? 0;

  /// 记住当前这一段的时间，数据变了以后回到它。
  void _rememberAnchor() => _anchor = _data?.windowAt(_index)?.start;

  /// **所有暂停都对齐**：停住，并落到最近的一个时间点（往前的方向）。
  void _pauseAligned() {
    _rememberAnchor();
    if (_playing) _playback.stop();
    final data = _data;
    if (data != null) {
      _playback.value = data.snapToWindow(_playback.value);
      _anchor = data.windowAt(_index)?.start;
    }
    setState(() {});
  }

  void _toggle() {
    if (_playing) {
      _pauseAligned();
      return;
    }
    // 从当前这一段往前播；已经到末尾就从头来
    if (_playback.value >= 1) _playback.value = 0;
    _anchor = null;
    _playback.forward();
    setState(() {});
  }

  /// 快一点 / 慢一点：只往前播，不动位置；正在播就按新速度接着播
  /// （播放过程中唯一允许"不打断"的调整）。
  void _nudgeSpeed(int delta) {
    final index = _speeds.indexOf(_speed);
    final next = _speeds[(index < 0 ? _speeds.indexOf(1) : index) + delta];
    setState(() => _speed = next);
    _playback.duration = _durationFor(_segments);
    if (_playing) _playback.forward();
  }

  /// 拖进度条：拖动过程跟手（连续），松手时由控制条吸附。
  void _seek(double value) {
    if (_playing) _playback.stop();
    _playback.value = value.clamp(0.0, 1.0);
    _rememberAnchor();
    setState(() {});
  }

  /// 滑动切段：左滑/下滑 = 上一段，右滑/上滑 = 下一段；一滑动就中止动画。
  void _onSwipe() {
    final data = _data;
    final delta = _swipe;
    _swipe = Offset.zero;
    if (data == null || delta.distance < _swipeSlop) return;
    final forward = delta.dx.abs() >= delta.dy.abs()
        ? delta.dx >
              0 // 右滑 = 下一段
        : delta.dy < 0; // 上滑 = 下一段
    _step(forward ? 1 : -1);
  }

  void _step(int delta) {
    final data = _data;
    if (data == null) return;
    if (_playing) _playback.stop();
    final target = (_index + delta).clamp(data.activeFirst, data.activeLast);
    _playback.value = data.progressForWindow(target);
    _anchor = data.windowAt(target)?.start;
    setState(() {});
  }

  /// 换模式：暂停动画，但停在**同一个时间点**上。
  void _setMode(WordCloudPlayMode mode) {
    if (mode == _mode) return;
    _rememberAnchor();
    if (_playing) _playback.stop();
    setState(() => _mode = mode);
  }

  /// 应用新的时间轴参数：暂停动画，并保留当前时间点（数据回来后重新定位）。
  void _applyTimeline(WordCloudTimeline next) {
    if (next == _timeline) return;
    _rememberAnchor();
    if (_playing) _playback.stop();
    setState(() {
      _timeline = next;
      _segments = 0;
    });
  }

  /// 数据重算后把进度挪回锚点所在的那一段（锚点没了就靠它最近的一段）。
  void _reanchor(WordCloudData data) {
    final anchor = _anchor;
    if (anchor == null) return;
    _anchor = null;
    final index = data.windowIndexAt(anchor);
    // 构建期间不能改 notifier（会触发正在构建的后代重绘），放到下一帧。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _playback.value = data.progressForWindow(index);
    });
  }

  /// 自定义范围：走日历式的选择器页面。
  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final result = await WordCloudRangeRoute(
      start: _timeline.startAt(now).toIso8601String(),
      end: _timeline
          .endExclusiveAt(now)
          .subtract(const Duration(days: 1))
          .toIso8601String(),
    ).push<WordCloudRangeResult>(context);
    if (result == null) return;
    // 保留用户选过的「每张看多久」
    _applyTimeline(
      _timeline.withRange(
        preset: WordCloudRangePreset.custom,
        customStart: result.start,
        customEnd: result.end,
      ),
    );
  }

  Future<void> _showWord(WordCloudData data, PlacedWord placed) async {
    final term = data.terms.firstWhere((t) => t.word == placed.word);
    final l10n = context.l10n;
    await MSheet.show<void>(
      context,
      builder: (sheetContext) => MSheetScaffold<void>(
        title: term.word,
        icon: LucideIcons.hash,
        actions: [MAction(label: l10n.common.ok, isPrimary: true)],
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            Text(
              l10n.wordcloud.wordCount(count: term.total),
              style: context.theme.typography.bodyMedium.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            _WindowBars(term: term, data: data),
            const SizedBox(height: 6),
            Text(
              l10n.wordcloud.windowBarsHint,
              style: context.theme.typography.labelSmall.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () {
                final added = ref
                    .read(wordCloudLexiconListProvider.notifier)
                    .add(term.word);
                Navigator.of(sheetContext).pop();
                if (added) {
                  HapticFeedback.mediumImpact();
                  toast.success(message: l10n.wordcloud.lexiconToast);
                }
              },
              icon: const Icon(LucideIcons.bookPlus),
              label: Text(l10n.wordcloud.lexiconAdd),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () {
                final added = ref
                    .read(wordCloudBlockedProvider.notifier)
                    .add(term.word);
                Navigator.of(sheetContext).pop();
                if (added) {
                  HapticFeedback.mediumImpact();
                  toast.success(message: l10n.wordcloud.blockedToast);
                }
              },
              icon: const Icon(LucideIcons.ban),
              label: Text(l10n.wordcloud.wordBlock),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(wordCloudDataProvider(timeline: _timeline));
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wordcloud.title),
        actions: [
          IconButton(
            tooltip: l10n.wordcloud.dictionaryTitle,
            icon: const Icon(LucideIcons.bookMarked),
            onPressed: () => const WordCloudDictionaryRoute().push(context),
          ),
        ],
      ),
      body: async.buildLoading(
        data: (data) =>
            data.isEmpty ? const _Empty() : _buildBody(context, data),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WordCloudData data) {
    _data = data;
    // 播放只在有词的段之间跑：空白时段已经被仓储剔掉了。
    _ensureDuration(data.segmentCount);
    // 数据重算过就回到原来那一段时间（不跳回开头，也不自动播）。
    _reanchor(data);

    final l10n = context.l10n;
    final plan = _timeline.planAt(DateTime.now());
    // 底部这条是固定的操作区，留出左右与底部的安全边距，别贴到屏幕圆角/手势区。
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: .fromLTRB(12, 8, 12, 8 + safeBottom),
      child: Column(
        children: [
          _RangeBar(
            title: _rangeTitle(),
            summary: _rangeSummary(l10n, data, plan),
            stats: l10n.wordcloud.subtitle(
              diaries: data.diaryCount,
              terms: data.terms.length,
            ),
            onTap: () => unawaited(_openTimelineSheet()),
          ),
          Expanded(
            // 词云区域内滑动切换：左滑/下滑上一段，右滑/上滑下一段；
            // 一滑动就中止动画（点击选词仍然由画布自己处理）。
            child: GestureDetector(
              onPanStart: (_) => _swipe = Offset.zero,
              onPanUpdate: (details) => _swipe += details.delta,
              onPanEnd: (_) => _onSwipe(),
              onPanCancel: () => _swipe = Offset.zero,
              child: WordCloudCanvas(
                data: data,
                progress: _progress,
                mode: _mode,
                onWordTap: (placed) => unawaited(_showWord(data, placed)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const .symmetric(horizontal: 8),
            child: _PlaybackBar(
              playback: _playback,
              data: data,
              mode: _mode,
              speed: _speed,
              canSlower: _speed > _speeds.first,
              canFaster: _speed < _speeds.last,
              onToggle: _toggle,
              onSeek: _seek,
              onSlower: () => _nudgeSpeed(-1),
              onFaster: () => _nudgeSpeed(1),
              onModeSelected: _setMode,
            ),
          ),
        ],
      ),
    );
  }

  /// 范围栏第一行：**选中的时间范围**（起止都写日期，不是预设名字）。
  String _rangeTitle() {
    final now = DateTime.now();
    return _formatRange(
      _timeline.startAt(now),
      _timeline.endExclusiveAt(now).subtract(const Duration(days: 1)),
    );
  }

  static String _formatRange(DateTime start, DateTime end) {
    final from = TimeFormat.anchorDate(start);
    final to = TimeFormat.anchorDate(end);
    return from == to ? from : '$from – $to';
  }

  String _rangeSummary(
    Translations l10n,
    WordCloudData data,
    WordCloudWindowPlan plan,
  ) {
    if (!plan.isValid) return _planError(l10n, plan.error);
    final size = l10n.wordcloud.windowSize(
      count: plan.length,
      unit: _unitLabel(l10n, plan.unit),
    );
    // 卡片数用**实际留下的窗口数**（空白的已经跳过），并说明跳掉了多少。
    final base = l10n.wordcloud.windowSummary(
      count: data.windowCount,
      size: size,
    );
    final skipped = plan.windowCount - data.windowCount;
    return skipped > 0
        ? '$base · ${l10n.wordcloud.windowSkipped(count: skipped)}'
        : base;
  }

  static String _unitLabel(Translations l10n, WordCloudUnit unit) =>
      switch (unit) {
        WordCloudUnit.day => l10n.wordcloud.unitDay,
        WordCloudUnit.week => l10n.wordcloud.unitWeek,
        WordCloudUnit.month => l10n.wordcloud.unitMonth,
        WordCloudUnit.quarter => l10n.wordcloud.unitQuarter,
        WordCloudUnit.year => l10n.wordcloud.unitYear,
      };

  static String _planError(Translations l10n, WordCloudPlanError? error) =>
      switch (error) {
        WordCloudPlanError.emptyRange => l10n.wordcloud.errEmptyRange,
        // 窗口参数已经不给用户调了，只剩下「范围太大 → 张数太多」这一条会出现
        WordCloudPlanError.badStep ||
        WordCloudPlanError.badLength ||
        WordCloudPlanError.tooManyWindows => l10n.wordcloud.errTooManyWindows,
        null => '',
      };

  /// 调**时间范围**与**每张看多久**（按周/月/季度/年）。
  /// 「多久换一张」固定在「每张看多久」上（每张不重叠），播放快慢在控制条上调。
  Future<void> _openTimelineSheet() async {
    var draft = _timeline;
    await MSheet.show<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final l10n = sheetContext.l10n;
          final now = DateTime.now();
          void apply(WordCloudTimeline next) {
            setSheet(() => draft = next);
            _applyTimeline(next);
          }

          final plan = draft.planAt(now);
          return MSheetScaffold<void>(
            title: l10n.wordcloud.timelineSheetTitle,
            icon: LucideIcons.calendarRange,
            actions: [MAction(label: l10n.common.ok, isPrimary: true)],
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                _SheetLabel(l10n.wordcloud.rangeTitle),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in WordCloudRangePreset.values)
                      ChoiceChip(
                        label: Text(_presetLabel(l10n, preset)),
                        selected: draft.preset == preset,
                        onSelected: (_) {
                          if (preset == WordCloudRangePreset.custom) {
                            unawaited(_pickCustomRange());
                            return;
                          }
                          apply(draft.withRange(preset: preset));
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatRange(
                    draft.startAt(now),
                    draft.endExclusiveAt(now).subtract(const Duration(days: 1)),
                  ),
                  style: sheetContext.theme.typography.titleSmall.onSurface,
                ),
                const SizedBox(height: 16),
                _SheetLabel(l10n.wordcloud.windowLengthTitle),
                SegmentedButton<WordCloudUnit>(
                  showSelectedIcon: false,
                  selected: {draft.unitAt(now)},
                  segments: [
                    for (final unit in wordCloudLengthUnits)
                      ButtonSegment(
                        value: unit,
                        label: Text(_unitLabel(l10n, unit)),
                      ),
                  ],
                  onSelectionChanged: (selection) =>
                      apply(draft.withUnit(selection.first)),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.wordcloud.windowLengthHint,
                  style:
                      sheetContext.theme.typography.labelSmall.onSurfaceVariant,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const .all(12),
                  decoration: BoxDecoration(
                    color: plan.isValid
                        ? sheetContext.theme.colors.surfaceContainerHigh
                        : sheetContext.theme.colors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      Text(
                        plan.isValid
                            ? l10n.wordcloud.windowAtMost(
                                count: plan.windowCount,
                                size: l10n.wordcloud.windowSize(
                                  count: plan.length,
                                  unit: _unitLabel(l10n, plan.unit),
                                ),
                              )
                            : _planError(l10n, plan.error),
                        style: sheetContext
                            .theme
                            .typography
                            .labelLarge
                            .emphasized
                            .onSurface,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        plan.isValid
                            ? _preview(l10n, plan)
                            : l10n.wordcloud.windowKeepLast,
                        style: sheetContext
                            .theme
                            .typography
                            .labelSmall
                            .onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _presetLabel(Translations l10n, WordCloudRangePreset preset) =>
      switch (preset) {
        WordCloudRangePreset.week => l10n.wordcloud.rangeWeek,
        WordCloudRangePreset.month => l10n.wordcloud.rangeMonth,
        WordCloudRangePreset.year => l10n.wordcloud.rangeYear,
        WordCloudRangePreset.custom => l10n.wordcloud.rangeCustom,
      };

  /// 前几张的时间落点，让参数可预期。
  static String _preview(Translations l10n, WordCloudWindowPlan plan) {
    final head = plan.windows
        .take(3)
        .map((window) {
          final start = TimeFormat.anchorDate(window.start);
          final end = TimeFormat.anchorDate(
            window.endExclusive.subtract(const Duration(days: 1)),
          );
          return start == end ? start : '$start~$end';
        })
        .join(' / ');
    final more = plan.windowCount > 3
        ? ' …${l10n.wordcloud.windowPreviewMore(count: plan.windowCount - 3)}'
        : '';
    return '$head$more';
  }
}

/// 顶部：选时间范围（实际日期 + 派生出的张数；点它调整）。
class _RangeBar extends StatelessWidget {
  final String title;
  final String summary;
  final String stats;
  final VoidCallback onTap;

  const _RangeBar({
    required this.title,
    required this.summary,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final typo = theme.typography;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: const .all(.circular(18)),
      clipBehavior: .antiAlias,
      child: MInkWell(
        onTap: onTap,
        child: Padding(
          padding: const .fromLTRB(14, 10, 12, 10),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.calendarRange,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: typo.titleSmall.emphasized.onSurface,
                    ),
                  ),

                  Icon(
                    LucideIcons.chevronDown,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(summary, style: typo.labelLarge.onSurfaceVariant),
              const SizedBox(height: 1),
              Text(stats, style: typo.labelMedium.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部：播放控制（进度 + 播放/暂停 + 快慢 + 本段/累计开关）。
///
/// 进度条松手会**吸附到最近的一张**（分割点）——画面停在完整的一张上，
/// 而不是两张之间的插值；正好落在两张中间时按拖动方向取整。
class _PlaybackBar extends StatefulWidget {
  final Animation<double> playback;
  final WordCloudData data;
  final WordCloudPlayMode mode;
  final double speed;
  final bool canSlower;
  final bool canFaster;
  final VoidCallback onToggle;
  final ValueChanged<double> onSeek;
  final VoidCallback onSlower;
  final VoidCallback onFaster;
  final ValueChanged<WordCloudPlayMode> onModeSelected;

  const _PlaybackBar({
    required this.playback,
    required this.data,
    required this.mode,
    required this.speed,
    required this.canSlower,
    required this.canFaster,
    required this.onToggle,
    required this.onSeek,
    required this.onSlower,
    required this.onFaster,
    required this.onModeSelected,
  });

  @override
  State<_PlaybackBar> createState() => _PlaybackBarState();
}

class _PlaybackBarState extends State<_PlaybackBar> {
  /// 拖动方向：往前（右）为 true。只用来在"正好两张中间"时决定往哪边吸附。
  bool _forward = true;
  double _dragged = 0;

  void _onChangeStart(double value) {
    _dragged = value;
    widget.onSeek(value);
  }

  void _onChanged(double value) {
    _forward = value >= _dragged;
    _dragged = value;
    widget.onSeek(value);
  }

  /// 松手：吸附到最近的分割点。
  void _onChangeEnd(double value) {
    widget.onSeek(widget.data.snapToWindow(value, forward: _forward));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.theme.typography;
    final data = widget.data;
    // 直接听 AnimationController：播放/暂停图标才会在自动起播、播完这些
    // 程序化切换之后立刻跟上（只听 progress 的话过渡瞬间会慢半拍）。
    return ListenableBuilder(
      listenable: widget.playback,
      builder: (context, _) {
        final value = widget.playback.value;
        final playing = widget.playback.isAnimating;
        // 标签也按吸附后的张号走，和松手落点一致
        final index = data.nearestWindowAt(value, forward: _forward);
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _windowLabel(l10n, index),
                    style: typo.labelLarge.emphasized.onSurface,
                  ),
                ),
                Text(
                  // 张数（不是段间隔数）：10 张就是「第 i/10 张」
                  l10n.wordcloud.segmentLabel(
                    index: index - data.activeFirst + 1,
                    total: data.activeWindowCount,
                  ),
                  style: typo.labelSmall.outline,
                ),
              ],
            ),
            Slider(
              value: value.clamp(0.0, 1.0),
              onChangeStart: _onChangeStart,
              onChanged: _onChanged,
              onChangeEnd: _onChangeEnd,
            ),
            Row(
              children: [
                // 左半边：播放控制（往中间收一点，别贴屏幕圆角）
                _IconButton(
                  tooltip: playing ? l10n.wordcloud.pause : l10n.wordcloud.play,
                  icon: playing ? LucideIcons.pause : LucideIcons.play,
                  filled: true,
                  onPressed: widget.onToggle,
                ),
                const SizedBox(width: 2),
                _IconButton(
                  tooltip: l10n.wordcloud.slower,
                  icon: LucideIcons.chevronLeft,
                  onPressed: widget.canSlower ? widget.onSlower : null,
                ),
                _IconButton(
                  tooltip: l10n.wordcloud.faster,
                  icon: LucideIcons.chevronRight,
                  onPressed: widget.canFaster ? widget.onFaster : null,
                ),
                const SizedBox(width: 4),
                Text(
                  _speedLabel(widget.speed),
                  style: typo.labelMedium.emphasized.onSurfaceVariant,
                ),
                const Spacer(),
                Tooltip(
                  message: widget.mode == WordCloudPlayMode.perBucket
                      ? l10n.wordcloud.modePerBucketHint
                      : l10n.wordcloud.modeCumulativeHint,
                  child: SegmentedButton<WordCloudPlayMode>(
                    showSelectedIcon: false,
                    selected: {widget.mode},
                    segments: [
                      ButtonSegment(
                        value: WordCloudPlayMode.perBucket,
                        label: Text(l10n.wordcloud.modePerBucket),
                      ),
                      ButtonSegment(
                        value: WordCloudPlayMode.cumulative,
                        label: Text(l10n.wordcloud.modeCumulative),
                      ),
                    ],
                    onSelectionChanged: (selection) =>
                        widget.onModeSelected(selection.first),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _speedLabel(double speed) {
    final text = speed == speed.roundToDouble()
        ? speed.toStringAsFixed(0)
        : '$speed';
    return '$text×';
  }

  /// 当前这一张的区间。**带年份**，跨年时不会看糊。
  String _windowLabel(Translations l10n, int index) {
    final window = widget.data.windowAt(index);
    if (window == null) return '';
    final start = TimeFormat.anchorDate(window.start);
    final end = TimeFormat.anchorDate(window.lastMoment);
    if (widget.mode == WordCloudPlayMode.cumulative) {
      return l10n.wordcloud.upto(day: end);
    }
    return start == end
        ? start
        : l10n.wordcloud.windowRange(from: start, to: end);
  }
}

/// 统一尺寸的图标按钮（禁用时保留位置，不跳动）。
class _IconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool filled;
  final VoidCallback? onPressed;

  const _IconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => filled
      ? IconButton.filledTonal(
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: onPressed,
        )
      : IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onPressed);
}

/// 选中词在每张里的出现次数。
class _WindowBars extends StatelessWidget {
  final WordCloudTerm term;
  final WordCloudData data;

  const _WindowBars({required this.term, required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    var maxCount = 0;
    for (final count in term.counts) {
      if (count > maxCount) maxCount = count;
    }
    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: .end,
        children: [
          for (var i = 0; i < data.windowCount; i++)
            Expanded(
              child: Padding(
                padding: const .symmetric(horizontal: 1),
                child: Container(
                  height: maxCount <= 0
                      ? 2
                      : 2 + 34 * term.countAt(i) / maxCount,
                  decoration: BoxDecoration(
                    color: term.countAt(i) > 0
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    borderRadius: const .vertical(top: .circular(2)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .only(bottom: 6),
    child: Text(
      text,
      style: context.theme.typography.labelMedium.emphasized.onSurfaceVariant,
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(
            LucideIcons.cloudOff,
            size: 48,
            color: theme.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.wordcloud.emptyTitle,
            style: theme.typography.titleMedium.onSurface,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const .symmetric(horizontal: 40),
            child: Text(
              l10n.wordcloud.emptyDesc,
              textAlign: .center,
              style: theme.typography.bodySmall.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
