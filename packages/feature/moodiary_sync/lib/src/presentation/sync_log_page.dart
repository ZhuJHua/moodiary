import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/application/sync_log_runs.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/presentation/widget/sync_labels.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

/// 同步日志单页：默认展示今天并实时追加；可按 [SyncLogger] 的按天 jsonl 切换历史
/// 日期（保留 7 天，历史视图不追加实时事件）。
///
/// 显示单元是「一次同步」（[groupSyncRuns]）：方向 · 触发源 · 结果 · 耗时，展开
/// 才看逐条事件（段内连续同 kind 再折一层）。所有行走同一个 [_LogRow] 网格——
/// 时间 / 图标 / 文本 / 尾部四列在任何层级都对齐。
class SyncLogPage extends StatefulWidget {
  const SyncLogPage({super.key});

  @override
  State<SyncLogPage> createState() => _SyncLogPageState();
}

enum _Filter { all, problems }

class _SyncLogPageState extends State<SyncLogPage> {
  /// 显示中的原始事件（顺序无所谓，分组时排序）。
  List<SyncEvent> _events = const [];
  StreamSubscription<SyncEvent>? _sub;
  bool _loading = true;
  _Filter _filter = .all;

  DateTime _selectedDay = .now();

  /// 用户手动展开 / 收起过的段（键见 [_runKey]）；没动过的按默认规则。
  final Map<String, bool> _expanded = {};

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _viewingToday => _sameDay(_selectedDay, .now());

  @override
  void initState() {
    super.initState();
    // 先订阅再读文件，把订阅期间到达的事件并入，避免漏掉（仅今天视图）。
    final pending = <SyncEvent>[];
    _sub = getIt<SyncLogger>().events.listen((event) {
      if (!mounted || !_viewingToday) return;
      if (_loading) {
        pending.add(event);
      } else {
        setState(() => _events = [..._events, event]);
      }
    });
    _loadDay(.now(), pendingDuringLoad: pending);
  }

  Future<void> _loadDay(
    DateTime day, {
    List<SyncEvent>? pendingDuringLoad,
  }) async {
    setState(() {
      _selectedDay = day;
      _loading = true;
      _events = const [];
      _expanded.clear();
    });
    final fromFile = await getIt<SyncLogger>().readDay(day);
    if (!mounted || !_sameDay(_selectedDay, day)) return;
    setState(() {
      _events = [...fromFile, ...?pendingDuringLoad];
      _loading = false;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final days = await getIt<SyncLogger>().availableDays();
    // 今天可能还没有日志文件，但作为实时视图始终可选。
    final today = DateTime.now();
    if (!days.any((d) => _sameDay(d, today))) {
      days.insert(0, today);
    }
    if (!mounted) return;
    // 选中态按 == 比对，得挑出列表里那一份实例（_selectedDay 带时分秒，对不上）。
    DateTime? selected;
    for (final day in days) {
      if (_sameDay(day, _selectedDay)) selected = day;
    }
    final picked = await MSheet.picker<DateTime>(
      context,
      title: l10n.sync.logPickDate,
      icon: LucideIcons.calendarDays,
      selected: selected,
      options: [
        for (final day in days)
          MSheetOption(
            value: day,
            label:
                TimeFormat.isoDate(day) +
                (_sameDay(day, today) ? l10n.sync.logTodaySuffix : ''),
            icon: _sameDay(day, today)
                ? LucideIcons.calendarCheck
                : LucideIcons.calendarDays,
          ),
      ],
    );
    if (picked != null && mounted && !_sameDay(picked, _selectedDay)) {
      await _loadDay(picked);
    }
  }

  Future<void> _onClearLogs() async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.sync.logClear,
      message: l10n.sync.logClearMessage,
      confirmLabel: l10n.diary.recycleClearConfirm,
      isDestructive: true,
    );
    if (!confirmed) return;
    await getIt<SyncLogger>().clearAll();
    if (!mounted) return;
    setState(() => _events = const []);
  }

  static String _runKey(SyncLogRun run) =>
      '${run.start.at.microsecondsSinceEpoch}-${run.direction ?? ''}';

  /// 默认只展开最新一次和出了问题的——打开日志页多半是想看「刚才那次」。
  bool _isExpanded(SyncLogRun run, {required bool newest}) =>
      _expanded[_runKey(run)] ?? (newest || run.hasProblem || run.open);

  @override
  Widget build(BuildContext context) {
    final entries = groupSyncRuns(_events);
    final visible = _filter == .problems
        ? entries.where((e) => e.hasProblem).toList()
        : entries;
    final runs = entries.whereType<SyncLogRun>().length;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.sync.logTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.sync.logFilterByDate,
            icon: const Icon(LucideIcons.calendarDays),
            onPressed: _pickDay,
          ),
          IconButton(
            tooltip: context.l10n.sync.logClear,
            icon: const Icon(LucideIcons.eraser),
            onPressed: _onClearLogs,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: const .fromLTRB(20, 10, 20, 4),
            child: Row(
              children: [
                Text(
                  _viewingToday
                      ? context.l10n.sync.logToday
                      : TimeFormat.isoDate(_selectedDay),
                  style: context.theme.typography.labelLarge.onSurfaceVariant,
                ),
                const Spacer(),
                if (!_loading)
                  Text(
                    context.l10n.sync.logRunCount(
                      runs: runs,
                      events: _events.length,
                    ),
                    style: context.theme.typography.bodySmall.outline,
                  ),
              ],
            ),
          ),
          MChipBar<_Filter>(
            items: [
              MChipData(value: .all, label: context.l10n.sync.logFilterAll),
              MChipData(
                value: .problems,
                label: context.l10n.sync.logFilterProblems,
                icon: LucideIcons.triangleAlert,
              ),
            ],
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? const _Empty()
                : ListView.builder(
                    padding: const .fromLTRB(8, 0, 8, 8),
                    itemCount: visible.length,
                    itemBuilder: (context, index) => switch (visible[index]) {
                      final SyncLogRun run => _RunTile(
                        run: run,
                        expanded: _isExpanded(run, newest: index == 0),
                        onToggle: () => setState(
                          () => _expanded[_runKey(run)] = !_isExpanded(
                            run,
                            newest: index == 0,
                          ),
                        ),
                      ),
                      final SyncLogSingle single => _EventRow(
                        event: single.event,
                      ),
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(LucideIcons.cloudSync, size: 40, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            context.l10n.sync.logEmpty,
            textAlign: .center,
            style: context.theme.typography.bodyMedium.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── 文案 / 图标映射 ───────────────────────

/// kind → 图标 / 文案，都用 switch 而不是 Map：加了新 kind 忘了配就编译报错，
/// Map + `?? kind.name` 只会静默漏出原始枚举名（mediaInfo 那五个就这么漏过）。
IconData _kindIcon(SyncEventKind kind) => switch (kind) {
  .syncStart => LucideIcons.play,
  .syncEnd => LucideIcons.flag,
  .manifestRead => LucideIcons.list,
  .manifestWrite => LucideIcons.filePenLine,
  .diaryUpload => LucideIcons.upload,
  .diaryDownload => LucideIcons.download,
  .diarySkip => LucideIcons.skipForward,
  .diaryTombstonePush => LucideIcons.eraser,
  .diaryTombstonePull => LucideIcons.trash2,
  .categoryUpload => LucideIcons.upload,
  .categoryDownload => LucideIcons.download,
  .categorySkip => LucideIcons.skipForward,
  .categoryTombstonePush => LucideIcons.eraser,
  .categoryTombstonePull => LucideIcons.trash2,
  .mediaInfoUpload => LucideIcons.fileUp,
  .mediaInfoDownload => LucideIcons.fileDown,
  .mediaInfoSkip => LucideIcons.skipForward,
  .mediaInfoTombstonePush => LucideIcons.eraser,
  .mediaInfoTombstonePull => LucideIcons.trash2,
  .mediaUpload => LucideIcons.cloudUpload,
  .mediaDownload => LucideIcons.cloudDownload,
  .mediaSkip => LucideIcons.skipForward,
  .mediaDelete => LucideIcons.trash2,
  .lockAcquire => LucideIcons.lock,
  .lockRelease => LucideIcons.lockOpen,
  .keyfileUpload => LucideIcons.keyRound,
  .keyConflict => LucideIcons.shieldAlert,
  .reCipher => LucideIcons.refreshCcw,
  .error => LucideIcons.circleAlert,
};

String _kindLabel(Translations l10n, SyncEventKind kind) => switch (kind) {
  .syncStart => l10n.sync.kindSyncStart,
  .syncEnd => l10n.sync.kindSyncEnd,
  .manifestRead => l10n.sync.kindManifestRead,
  .manifestWrite => l10n.sync.kindManifestWrite,
  .diaryUpload => l10n.sync.kindDiaryUpload,
  .diaryDownload => l10n.sync.kindDiaryDownload,
  .diarySkip => l10n.sync.kindDiarySkip,
  .diaryTombstonePush => l10n.sync.kindDiaryTombstonePush,
  .diaryTombstonePull => l10n.sync.kindDiaryTombstonePull,
  .categoryUpload => l10n.sync.kindCategoryUpload,
  .categoryDownload => l10n.sync.kindCategoryDownload,
  .categorySkip => l10n.sync.kindCategorySkip,
  .categoryTombstonePush => l10n.sync.kindCategoryTombstonePush,
  .categoryTombstonePull => l10n.sync.kindCategoryTombstonePull,
  .mediaInfoUpload => l10n.sync.kindMediaInfoUpload,
  .mediaInfoDownload => l10n.sync.kindMediaInfoDownload,
  .mediaInfoSkip => l10n.sync.kindMediaInfoSkip,
  .mediaInfoTombstonePush => l10n.sync.kindMediaInfoTombstonePush,
  .mediaInfoTombstonePull => l10n.sync.kindMediaInfoTombstonePull,
  .mediaUpload => l10n.sync.kindMediaUpload,
  .mediaDownload => l10n.sync.kindMediaDownload,
  .mediaSkip => l10n.sync.kindMediaSkip,
  .mediaDelete => l10n.sync.kindMediaDelete,
  .lockAcquire => l10n.sync.kindLockAcquire,
  .lockRelease => l10n.sync.kindLockRelease,
  .keyfileUpload => l10n.sync.kindKeyfileUpload,
  .keyConflict => l10n.sync.kindKeyConflict,
  .reCipher => l10n.sync.kindReCipher,
  .error => l10n.sync.kindError,
};

String? _directionLabel(Translations l10n, String? direction) =>
    switch (direction) {
      'pull' => l10n.sync.directionPull,
      'push' => l10n.sync.directionPush,
      'restore' => l10n.sync.directionRestore,
      're-cipher' => l10n.sync.directionReCipher,
      _ => null,
    };

IconData _directionIcon(String? direction) => switch (direction) {
  'push' => LucideIcons.cloudUpload,
  'pull' || 'restore' => LucideIcons.cloudDownload,
  're-cipher' => LucideIcons.refreshCcw,
  _ => LucideIcons.refreshCw,
};

/// 从 payload 提取事件的一行摘要（方向 / 条数 / 标题 / 文件名…），与 kind 标签
/// 拼成「上传日记 · 我的周末」这样的日志行。取不到返回 null。
String? _subjectOf(Translations l10n, SyncEvent event) {
  final payload = event.payload ?? const {};
  String? str(String key) {
    final v = payload[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  return switch (event.kind) {
    .syncStart || .syncEnd => [
      ?_directionLabel(l10n, str('direction')),
      ?syncTriggerLabelOf(l10n, payload['trigger']),
    ].join(' · '),
    .manifestRead || .manifestWrite =>
      payload['entries'] is int
          ? l10n.sync.logEventCount(count: payload['entries'] as int)
          : null,
    // 失败事件多半只带原始 manifest key（条目还没解析出来就炸了），兜到 key
    // 才不会渲染成光秃秃一句「下载日记」、看不出是哪条红了。
    .diaryUpload ||
    .diaryDownload ||
    .diarySkip ||
    .diaryTombstonePush ||
    .diaryTombstonePull => str('title') ?? str('diaryId') ?? str('key'),
    .categoryUpload ||
    .categoryDownload ||
    .categorySkip ||
    .categoryTombstonePush ||
    .categoryTombstonePull => str('categoryId') ?? str('key'),
    .mediaInfoUpload ||
    .mediaInfoDownload ||
    .mediaInfoSkip ||
    .mediaInfoTombstonePush ||
    .mediaInfoTombstonePull => str('mediaFileName') ?? str('key'),
    .mediaUpload || .mediaDownload || .mediaSkip => str('filename'),
    .mediaDelete => str('ref') ?? str('filename'),
    .reCipher =>
      str('diaryId') ??
          str('categoryId') ??
          str('mediaFileName') ??
          str('ref') ??
          str('path'),
    .error => str('key') ?? str('path') ?? str('ref'),
    .keyfileUpload || .keyConflict || .lockAcquire || .lockRelease => null,
  };
}

/// [SyncEventReason] 的展示文案；同一 kind 下的细分语义（如各种「跳过」的原因）。
String? _reasonLabel(Translations l10n, SyncEventReason? reason) {
  if (reason == null) return null;
  return switch (reason) {
    .upToDate => l10n.sync.reasonUpToDate,
    .remoteNewer => l10n.sync.reasonRemoteNewer,
    .localNewer => l10n.sync.reasonLocalNewer,
    .openDiary => l10n.sync.reasonOpenDiary,
    .localMissing => l10n.sync.reasonLocalMissing,
    .probeFailed => l10n.sync.reasonProbeFailed,
    .recovered => l10n.sync.reasonRecovered,
    .remoteExists => l10n.sync.reasonRemoteExists,
    .localExists => l10n.sync.reasonLocalExists,
    .remoteMissing => l10n.sync.reasonRemoteMissing,
    .takeover => l10n.sync.reasonTakeover,
    .expiredLock => l10n.sync.reasonExpiredLock,
    .casVerified => l10n.sync.reasonCasVerified,
    .casUnsupported => l10n.sync.reasonCasUnsupported,
    .renewFailed => l10n.sync.reasonRenewFailed,
    .releaseFailed => l10n.sync.reasonReleaseFailed,
    .decodeFailed => l10n.sync.reasonDecodeFailed,
    .unknownTombstone => l10n.sync.reasonUnknownTombstone,
    .stopped => l10n.sync.reasonStopped,
    .aborted => l10n.sync.reasonAborted,
  };
}

Color _levelColor(BuildContext context, SyncEventLevel level) {
  final scheme = context.theme.colors;
  return switch (level) {
    .error => scheme.error,
    .warn => scheme.tertiary,
    .info => scheme.onSurfaceVariant,
  };
}

// ─────────────────────── 行网格 ───────────────────────

/// 所有日志行共用的四列网格：时间 58 · 图标 18 · 文本 · 尾部 16。段头、段内子项、
/// 折叠组头、散落事件都是它，只换背景与尾部——这样任何层级的时间与图标都对齐，
/// 不再有 ExpansionTile 与自绘行各画各的。
class _LogRow extends StatelessWidget {
  final DateTime at;
  final IconData icon;
  final Color iconColor;
  final Widget text;
  final Widget? trailing;
  final Color? background;
  final bool nested;
  final VoidCallback? onTap;

  const _LogRow({
    required this.at,
    required this.icon,
    required this.iconColor,
    required this.text,
    this.trailing,
    this.background,
    this.nested = false,
    this.onTap,
  });

  static const double timeWidth = 58;
  static const double iconSize = 18;
  static const double gap = 10;
  static const double trailingWidth = 16;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    return MInkWell(
      borderRadius: .circular(10),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const .symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: .circular(10),
          // 子项：左缘一条 2px 轨，列位不动。
          border: nested
              ? Border(left: BorderSide(color: scheme.outlineVariant, width: 2))
              : null,
        ),
        child: Row(
          crossAxisAlignment: .center,
          children: [
            SizedBox(
              width: timeWidth,
              child: Text(
                TimeFormat.timeHms(at),
                style: typography.bodySmall.outline.copyWith(
                  fontFeatures: const [.tabularFigures()],
                ),
              ),
            ),
            SizedBox(
              width: iconSize,
              child: Icon(icon, size: iconSize, color: iconColor),
            ),
            const SizedBox(width: gap),
            Expanded(child: text),
            SizedBox(width: trailingWidth, child: trailing),
          ],
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  final bool expanded;

  const _Chevron({required this.expanded});

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: expanded ? 0.5 : 0,
    duration: const Duration(milliseconds: 200),
    child: Icon(
      LucideIcons.chevronDown,
      size: 16,
      color: context.theme.colors.outline,
    ),
  );
}

// ─────────────────────── 一次同步 ───────────────────────

class _RunTile extends StatelessWidget {
  final SyncLogRun run;
  final bool expanded;
  final VoidCallback onToggle;

  const _RunTile({
    required this.run,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final outcome = run.outcome;
    final failed = outcome == .failed;
    final headline = [
      _directionLabel(l10n, run.direction) ?? _kindLabel(l10n, .syncStart),
      ?syncTriggerLabelOf(l10n, run.trigger),
    ].join(' · ');
    final elapsed = run.elapsed;

    return Padding(
      padding: const .only(top: 6),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          _LogRow(
            at: run.start.at,
            icon: _directionIcon(run.direction),
            iconColor: failed
                ? scheme.error
                : run.hasProblem
                ? scheme.tertiary
                : scheme.primary,
            background: scheme.surfaceContainerHighest,
            onTap: onToggle,
            trailing: _Chevron(expanded: expanded),
            text: Row(
              children: [
                Flexible(
                  child: Text(
                    headline,
                    overflow: .ellipsis,
                    style: failed
                        ? typography.bodyMedium.emphasized.error
                        : typography.bodyMedium.emphasized.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                _OutcomeChip(run: run),
                if (elapsed != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    syncElapsedLabel(l10n, elapsed),
                    style: typography.bodySmall.outline.copyWith(
                      fontFeatures: const [.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: .topCenter,
            child: expanded
                ? Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      for (final entry in foldSameKind(run.events))
                        switch (entry) {
                          final SyncEvent e => _EventRow(
                            event: e,
                            nested: true,
                          ),
                          final List<SyncEvent> group => _FoldTile(
                            events: group,
                          ),
                          _ => const SizedBox.shrink(),
                        },
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// 段头上的结果胶囊：已是最新 / ↑ 1 · 媒体 2 / 失败 / 未完成 / 已停止 / 进行中。
class _OutcomeChip extends StatelessWidget {
  final SyncLogRun run;

  const _OutcomeChip({required this.run});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final (label, fg, bg) = switch (run.outcome) {
      null => (
        l10n.sync.statusRunning,
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHigh,
      ),
      .failed => (
        l10n.sync.logRunFailed,
        scheme.error,
        scheme.error.withValues(alpha: 0.12),
      ),
      .partial => (
        '${l10n.sync.logRunPartial} · ${run.failedCount}',
        scheme.tertiary,
        scheme.tertiaryContainer,
      ),
      .stopped => (
        l10n.sync.logRunStopped,
        scheme.tertiary,
        scheme.tertiaryContainer,
      ),
      .upToDate => (
        l10n.sync.logRunUpToDate,
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHigh,
      ),
      .changed => (
        [
          if (run.changedCount > 0)
            '${run.direction == 'push' ? '↑' : '↓'} ${run.changedCount}',
          if (run.mediaCount > 0) l10n.sync.summaryMedia(count: run.mediaCount),
        ].join(' · '),
        scheme.primary,
        scheme.primaryContainer.withValues(alpha: 0.6),
      ),
    };
    return Container(
      padding: const .symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: .circular(999)),
      child: Text(
        label,
        style: typography.labelSmall.onSurface.copyWith(
          color: fg,
          fontFeatures: const [.tabularFigures()],
        ),
      ),
    );
  }
}

/// 段内连续同 kind 的折叠组（≥2 条），如「跳过日记 · 127 条 · 本地不旧于远端」。
class _FoldTile extends StatefulWidget {
  final List<SyncEvent> events;

  const _FoldTile({required this.events});

  @override
  State<_FoldTile> createState() => _FoldTileState();
}

class _FoldTileState extends State<_FoldTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typography = context.theme.typography;
    final events = widget.events;
    final kind = events.first.kind;
    final worst = events.fold<SyncEventLevel>(
      .info,
      (acc, e) => e.level.index > acc.index ? e.level : acc,
    );
    // 组内 reason 一致才写进组头（多半如此：一串「本地不旧于远端」）。
    final reasons = {for (final e in events) e.reason};
    final line = [
      l10n.sync.logGroupCount(
        kind: _kindLabel(l10n, kind),
        count: events.length,
      ),
      if (reasons.length == 1) ?_reasonLabel(l10n, reasons.single),
    ].join(' · ');

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        _LogRow(
          at: events.first.at,
          icon: _kindIcon(kind),
          iconColor: _levelColor(context, worst),
          nested: true,
          onTap: () => setState(() => _expanded = !_expanded),
          trailing: _Chevron(expanded: _expanded),
          text: Text(
            line,
            overflow: .ellipsis,
            style: worst == .error
                ? typography.bodyMedium.error
                : typography.bodyMedium.onSurface,
          ),
        ),
        if (_expanded)
          for (final e in events) _EventRow(event: e, nested: true),
      ],
    );
  }
}

// ─────────────────────── 单条事件 ───────────────────────

class _EventRow extends StatelessWidget {
  final SyncEvent event;
  final bool nested;

  const _EventRow({required this.event, this.nested = false});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final hasPayload = event.payload != null && event.payload!.isNotEmpty;
    final isError = event.level == .error;
    // 事件本身只有机器字段：文案 = kind 标签 + payload 摘要 + reason，
    // 例如「上传日记 · 我的周末」「跳过媒体 · a.jpg · 本地文件缺失」。
    final line = [
      _kindLabel(l10n, event.kind),
      ?_subjectOf(l10n, event),
      ?_reasonLabel(l10n, event.reason),
    ].where((s) => s.isNotEmpty).join(' · ');

    return _LogRow(
      at: event.at,
      icon: _kindIcon(event.kind),
      iconColor: _levelColor(context, event.level),
      nested: nested,
      onTap: hasPayload ? () => _showPayloadSheet(context) : null,
      trailing: hasPayload
          ? Icon(LucideIcons.chevronRight, size: 16, color: scheme.outline)
          : null,
      text: Text(
        line,
        style: isError
            ? typography.bodyMedium.error
            : typography.bodyMedium.onSurface,
      ),
    );
  }

  void _showPayloadSheet(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert({
      'at': event.at.toIso8601String(),
      'level': event.level.name,
      'kind': event.kind.name,
      if (event.reason != null) 'reason': event.reason!.name,
      'payload': ?event.payload,
    });
    MSheet.show<void>(
      context,
      builder: (ctx) => MSheetScaffold<void>(
        title: l10n.sync.logDetail,
        subtitle: event.kind.name,
        icon: LucideIcons.fileJson,
        actions: [
          MAction(
            label: l10n.sync.logCopy,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: pretty));
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              toast.success(message: l10n.common.copied);
            },
          ),
          MAction(label: ctx.l10n.common.ok, isPrimary: true),
        ],
        child: SelectableText(
          pretty,
          style: context.theme.typography.bodySmall.onSurface.copyWith(
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
