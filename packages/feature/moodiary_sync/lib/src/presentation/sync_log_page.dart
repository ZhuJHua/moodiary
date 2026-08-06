import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';

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
    final picked = await showMoodiaryPickerSheet<DateTime>(
      context,
      title: '选择日期',
      icon: LucideIcons.calendarDays,
      selected: selected,
      options: [
        for (final day in days)
          MoodiarySheetOption(
            value: day,
            label:
                TimeFormat.isoDate(day) + (_sameDay(day, today) ? '（今天）' : ''),
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
    final confirmed = await showMoodiaryConfirm(
      context,
      title: '清空日志',
      message: '将删除内存中的事件流和按天滚动的所有 jsonl 文件，操作不可恢复。',
      confirmLabel: '清空',
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
        title: const Text('同步日志'),
        actions: [
          IconButton(
            tooltip: '按日期筛选',
            icon: const Icon(LucideIcons.calendarDays),
            onPressed: _pickDay,
          ),
          IconButton(
            tooltip: '清空日志',
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
                  _viewingToday ? '今天' : TimeFormat.isoDate(_selectedDay),
                  style: context.textTheme.labelLarge?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (!_loading)
                  Text(
                    '${_events.length} 条',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.outline,
                    ),
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
      final scheme = context.colorScheme;
      return Center(
        child: Column(
          mainAxisSize: .min,
          children: [
            Icon(LucideIcons.cloudSync, size: 40, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              '该日期暂无同步事件',
              textAlign: .center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
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

const _kindLabel = <SyncEventKind, String>{
  .syncStart: '同步开始',
  .syncEnd: '同步结束',
  .manifestRead: '读取清单',
  .manifestWrite: '写回清单',
  .diaryUpload: '上传日记',
  .diaryDownload: '下载日记',
  .diarySkip: '跳过日记',
  .diaryTombstonePush: '推送日记删除',
  .diaryTombstonePull: '同步日记删除',
  .categoryUpload: '上传分类',
  .categoryDownload: '下载分类',
  .categorySkip: '跳过分类',
  .categoryTombstonePush: '推送分类删除',
  .categoryTombstonePull: '同步分类删除',
  .mediaUpload: '上传媒体',
  .mediaDownload: '下载媒体',
  .mediaSkip: '跳过媒体',
  .mediaDelete: '删除媒体',
  .lockAcquire: '获取同步锁',
  .lockRelease: '释放同步锁',
  .error: '错误',
};

class _EventGroupTile extends StatelessWidget {
  /// 同 kind 的连续事件，最新在前。
  final List<SyncEvent> events;
  const _EventGroupTile({required this.events});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
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
      title: Text(
        '${_kindLabel[kind] ?? kind.name} · ${events.length} 条',
        style: context.textTheme.bodyMedium?.copyWith(
          color: hasError ? scheme.error : scheme.onSurface,
        ),
      ),
      subtitle: Text(
        range,
        style: context.textTheme.bodySmall?.copyWith(
          color: scheme.outline,
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
    final scheme = context.colorScheme;
    final isError = event.level == .error;
    final isWarn = event.level == .warn;
    final iconColor = isError
        ? scheme.error
        : isWarn
        ? scheme.tertiary
        : scheme.onSurfaceVariant;
    final icon = _kindIcon[event.kind] ?? LucideIcons.circleDot;
    final hasPayload = event.payload != null && event.payload!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
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
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: isError ? scheme.error : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      TimeFormat.timeHms(event.at),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
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
      ),
    );
  }

  void _showPayloadSheet(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert({
      'at': event.at.toIso8601String(),
      'level': event.level.name,
      'kind': event.kind.name,
      'message': event.message,
      if (event.payload != null) 'payload': event.payload,
    });
    showMoodiarySheet<void>(
      context,
      builder: (ctx) => MoodiarySheetScaffold<void>(
        title: '事件详情',
        subtitle: event.kind.name,
        icon: LucideIcons.fileJson,
        actions: [
          MoodiaryAction(
            label: '复制',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: pretty));
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              toast.success(message: '已复制到剪贴板');
            },
          ),
          MoodiaryAction(label: ctx.l10n.ok, isPrimary: true),
        ],
        child: SelectableText(
          pretty,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }
}
