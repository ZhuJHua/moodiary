import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

/// 同步日志单页：默认展示今天并实时追加；可按 [SyncLogger] 的按天 jsonl
/// 切换历史日期（保留 7 天，历史视图不追加实时事件）；连续同类事件折叠为组。
class SyncLogPage extends StatefulWidget {
  const SyncLogPage({super.key});

  @override
  State<SyncLogPage> createState() => _SyncLogPageState();
}

class _SyncLogPageState extends State<SyncLogPage> {
  /// 显示中的事件，**最新在前**。
  List<SyncEvent> _events = const [];
  StreamSubscription<SyncEvent>? _sub;
  bool _loading = true;

  DateTime _selectedDay = .now();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _viewingToday => _sameDay(_selectedDay, .now());

  @override
  void initState() {
    super.initState();
    // 先订阅再读文件，把订阅期间到达的事件并入，避免漏掉（仅今天视图）。
    final pending = <SyncEvent>[];
    _sub = SyncLogger.get().events.listen((event) {
      if (!mounted || !_viewingToday) return;
      if (_loading) {
        pending.add(event);
      } else {
        setState(() => _events = [event, ..._events]);
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
    });
    final fromFile = await SyncLogger.get().readDay(day);
    // 文件按时间升序、UI 要最新在前 → reversed
    final ordered = fromFile.reversed.toList();
    if (pendingDuringLoad != null && pendingDuringLoad.isNotEmpty) {
      ordered.insertAll(0, pendingDuringLoad.reversed);
    }
    if (!mounted || !_sameDay(_selectedDay, day)) return;
    setState(() {
      _events = ordered;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final days = await SyncLogger.get().availableDays();
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
    await SyncLogger.get().clearAll();
    if (!mounted) return;
    setState(() => _events = const []);
  }

  @override
  Widget build(BuildContext context) {
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
                    context.l10n.sync.logEventCount(count: _events.length),
                    style: context.theme.typography.bodySmall.outline,
                  ),
              ],
            ),
          ),
          Expanded(
            child: _EventList(events: _events, loading: _loading),
          ),
        ],
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  final List<SyncEvent> events;
  final bool loading;
  const _EventList({required this.events, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (events.isEmpty) {
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
    // 连续同类事件折叠成组（≥2 条），单条保持原样。
    final entries = <Object>[];
    var i = 0;
    while (i < events.length) {
      var j = i + 1;
      while (j < events.length && events[j].kind == events[i].kind) {
        j++;
      }
      final run = events.sublist(i, j);
      entries.add(run.length >= 2 ? run : run.first);
      i = j;
    }
    return ListView.builder(
      padding: const .fromLTRB(8, 0, 8, 8),
      itemCount: entries.length,
      itemBuilder: (context, index) => switch (entries[index]) {
        final SyncEvent event => _EventTile(event: event),
        final List<SyncEvent> group => _EventGroupTile(events: group),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

const _kindIcon = <SyncEventKind, IconData>{
  .syncStart: LucideIcons.play,
  .syncEnd: LucideIcons.flag,
  .manifestRead: LucideIcons.list,
  .manifestWrite: LucideIcons.filePenLine,
  .diaryUpload: LucideIcons.upload,
  .diaryDownload: LucideIcons.download,
  .diarySkip: LucideIcons.skipForward,
  .diaryTombstonePush: LucideIcons.eraser,
  .diaryTombstonePull: LucideIcons.trash2,
  .categoryUpload: LucideIcons.upload,
  .categoryDownload: LucideIcons.download,
  .categorySkip: LucideIcons.skipForward,
  .categoryTombstonePush: LucideIcons.eraser,
  .categoryTombstonePull: LucideIcons.trash2,
  .mediaUpload: LucideIcons.cloudUpload,
  .mediaDownload: LucideIcons.cloudDownload,
  .mediaSkip: LucideIcons.skipForward,
  .mediaDelete: LucideIcons.trash2,
  .lockAcquire: LucideIcons.lock,
  .lockRelease: LucideIcons.lockOpen,
  .error: LucideIcons.circleAlert,
};

Map<SyncEventKind, String> _kindLabel(Translations l10n) =>
    <SyncEventKind, String>{
      .syncStart: l10n.sync.kindSyncStart,
      .syncEnd: l10n.sync.kindSyncEnd,
      .manifestRead: l10n.sync.kindManifestRead,
      .manifestWrite: l10n.sync.kindManifestWrite,
      .diaryUpload: l10n.sync.kindDiaryUpload,
      .diaryDownload: l10n.sync.kindDiaryDownload,
      .diarySkip: l10n.sync.kindDiarySkip,
      .diaryTombstonePush: l10n.sync.kindDiaryTombstonePush,
      .diaryTombstonePull: l10n.sync.kindDiaryTombstonePull,
      .categoryUpload: l10n.sync.kindCategoryUpload,
      .categoryDownload: l10n.sync.kindCategoryDownload,
      .categorySkip: l10n.sync.kindCategorySkip,
      .categoryTombstonePush: l10n.sync.kindCategoryTombstonePush,
      .categoryTombstonePull: l10n.sync.kindCategoryTombstonePull,
      .mediaUpload: l10n.sync.kindMediaUpload,
      .mediaDownload: l10n.sync.kindMediaDownload,
      .mediaSkip: l10n.sync.kindMediaSkip,
      .mediaDelete: l10n.sync.kindMediaDelete,
      .lockAcquire: l10n.sync.kindLockAcquire,
      .lockRelease: l10n.sync.kindLockRelease,
      .error: l10n.sync.kindError,
    };

class _EventGroupTile extends StatefulWidget {
  /// 同 kind 的连续事件，最新在前。
  final List<SyncEvent> events;
  const _EventGroupTile({required this.events});

  @override
  State<_EventGroupTile> createState() => _EventGroupTileState();
}

class _EventGroupTileState extends State<_EventGroupTile> {
  /// 展开箭头自己维护角度：ExpansionTile 只在不传 trailing 时才给默认箭头包
  /// RotationTransition，传了就是纯静态 Widget。
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final events = widget.events;
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final kind = events.first.kind;
    // 组内最高严重级别决定组头配色，错误 / 警告不会被折叠埋掉。
    final hasError = events.any((e) => e.level == .error);
    final hasWarn = events.any((e) => e.level == .warn);
    final color = hasError
        ? scheme.error
        : hasWarn
        ? scheme.tertiary
        : scheme.onSurfaceVariant;
    final range =
        '${TimeFormat.timeHms(events.last.at)} – ${TimeFormat.timeHms(events.first.at)}';

    return ExpansionTile(
      // 用组内最旧事件做 key：列表实时增长时最旧端不变，新事件插入不会让
      // 展开状态错位到别的组。
      key: ValueKey('${kind.name}-${events.last.at.microsecondsSinceEpoch}'),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const .symmetric(horizontal: 10),
      childrenPadding: const .only(left: 12),
      visualDensity: .compact,
      leading: Icon(
        _kindIcon[kind] ?? LucideIcons.circleDot,
        size: 18,
        color: color,
      ),
      onExpansionChanged: (v) => setState(() => _expanded = v),
      trailing: AnimatedRotation(
        turns: _expanded ? 0.5 : 0,
        duration: const Duration(milliseconds: 200),
        child: Icon(LucideIcons.chevronDown, size: 20, color: scheme.outline),
      ),
      title: Text(
        context.l10n.sync.logGroupCount(
          kind: _kindLabel(context.l10n)[kind] ?? kind.name,
          count: events.length,
        ),
        style: hasError
            ? typography.bodyMedium.error
            : typography.bodyMedium.onSurface,
      ),
      subtitle: Text(
        range,
        style: typography.bodySmall.outline.copyWith(
          fontFeatures: const [.tabularFigures()],
        ),
      ),
      children: [for (final e in events) _EventTile(event: e)],
    );
  }
}

class _EventTile extends StatelessWidget {
  final SyncEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final isError = event.level == .error;
    final isWarn = event.level == .warn;
    final iconColor = isError
        ? scheme.error
        : isWarn
        ? scheme.tertiary
        : scheme.onSurfaceVariant;
    final icon = _kindIcon[event.kind] ?? LucideIcons.circleDot;
    final hasPayload = event.payload != null && event.payload!.isNotEmpty;

    return MInkWell(
      borderRadius: .circular(10),
      onTap: hasPayload ? () => _showPayloadSheet(context) : null,
      child: Padding(
        padding: const .symmetric(horizontal: 10, vertical: 7),
        child: Row(
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const .only(top: 1),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    event.message,
                    style: isError
                        ? typography.bodyMedium.error
                        : typography.bodyMedium.onSurface,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    TimeFormat.timeHms(event.at),
                    style: typography.bodySmall.outline.copyWith(
                      fontFeatures: const [.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (hasPayload)
              Padding(
                padding: const .only(top: 2),
                child: Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: scheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPayloadSheet(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert({
      'at': event.at.toIso8601String(),
      'level': event.level.name,
      'kind': event.kind.name,
      'message': event.message,
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
              toast.success(message: l10n.share.copied);
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
