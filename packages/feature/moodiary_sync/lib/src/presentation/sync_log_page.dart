import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
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

  DateTime _selectedDay = DateTime.now();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _viewingToday => _sameDay(_selectedDay, DateTime.now());

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
    _loadDay(DateTime.now(), pendingDuringLoad: pending);
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
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final day in days)
              ListTile(
                leading: Icon(
                  _sameDay(day, today)
                      ? Icons.today_rounded
                      : Icons.calendar_month_rounded,
                ),
                title: Text(
                  TimeFormat.isoDate(day) +
                      (_sameDay(day, today) ? '（今天）' : ''),
                ),
                trailing: _sameDay(day, _selectedDay)
                    ? Icon(
                        Icons.check_rounded,
                        color: ctx.colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(day),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted && !_sameDay(picked, _selectedDay)) {
      await _loadDay(picked);
    }
  }

  Future<void> _onClearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('将删除内存中的事件流和按天滚动的所有 jsonl 文件，操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: _pickDay,
          ),
          IconButton(
            tooltip: '清空日志',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _onClearLogs,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Row(
              children: [
                Text(
                  _viewingToday
                      ? '今天'
                      : TimeFormat.isoDate(_selectedDay),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_sync_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              '该日期暂无同步事件',
              textAlign: TextAlign.center,
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
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
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
  SyncEventKind.syncStart: Icons.play_arrow_rounded,
  SyncEventKind.syncEnd: Icons.flag_outlined,
  SyncEventKind.manifestRead: Icons.list_alt_rounded,
  SyncEventKind.manifestWrite: Icons.edit_note_rounded,
  SyncEventKind.diaryUpload: Icons.upload_rounded,
  SyncEventKind.diaryDownload: Icons.download_rounded,
  SyncEventKind.diarySkip: Icons.skip_next_rounded,
  SyncEventKind.diaryTombstonePush: Icons.delete_sweep_outlined,
  SyncEventKind.diaryTombstonePull: Icons.delete_outline,
  SyncEventKind.categoryUpload: Icons.upload_rounded,
  SyncEventKind.categoryDownload: Icons.download_rounded,
  SyncEventKind.categorySkip: Icons.skip_next_rounded,
  SyncEventKind.categoryTombstonePush: Icons.delete_sweep_outlined,
  SyncEventKind.categoryTombstonePull: Icons.delete_outline,
  SyncEventKind.mediaUpload: Icons.cloud_upload_outlined,
  SyncEventKind.mediaDownload: Icons.cloud_download_outlined,
  SyncEventKind.mediaSkip: Icons.skip_next_rounded,
  SyncEventKind.mediaDelete: Icons.delete_outline,
  SyncEventKind.lockAcquire: Icons.lock_outline,
  SyncEventKind.lockRelease: Icons.lock_open,
  SyncEventKind.error: Icons.error_outline,
};

const _kindLabel = <SyncEventKind, String>{
  SyncEventKind.syncStart: '同步开始',
  SyncEventKind.syncEnd: '同步结束',
  SyncEventKind.manifestRead: '读取清单',
  SyncEventKind.manifestWrite: '写回清单',
  SyncEventKind.diaryUpload: '上传日记',
  SyncEventKind.diaryDownload: '下载日记',
  SyncEventKind.diarySkip: '跳过日记',
  SyncEventKind.diaryTombstonePush: '推送日记删除',
  SyncEventKind.diaryTombstonePull: '同步日记删除',
  SyncEventKind.categoryUpload: '上传分类',
  SyncEventKind.categoryDownload: '下载分类',
  SyncEventKind.categorySkip: '跳过分类',
  SyncEventKind.categoryTombstonePush: '推送分类删除',
  SyncEventKind.categoryTombstonePull: '同步分类删除',
  SyncEventKind.mediaUpload: '上传媒体',
  SyncEventKind.mediaDownload: '下载媒体',
  SyncEventKind.mediaSkip: '跳过媒体',
  SyncEventKind.mediaDelete: '删除媒体',
  SyncEventKind.lockAcquire: '获取同步锁',
  SyncEventKind.lockRelease: '释放同步锁',
  SyncEventKind.error: '错误',
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
    final hasError = events.any((e) => e.level == SyncEventLevel.error);
    final hasWarn = events.any((e) => e.level == SyncEventLevel.warn);
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
      key: ValueKey(
        '${kind.name}-${events.last.at.microsecondsSinceEpoch}',
      ),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 10),
      childrenPadding: const EdgeInsets.only(left: 12),
      visualDensity: VisualDensity.compact,
      leading: Icon(
        _kindIcon[kind] ?? Icons.circle_outlined,
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
          fontFeatures: const [FontFeature.tabularFigures()],
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
    final isError = event.level == SyncEventLevel.error;
    final isWarn = event.level == SyncEventLevel.warn;
    final iconColor = isError
        ? scheme.error
        : isWarn
        ? scheme.tertiary
        : scheme.onSurfaceVariant;
    final icon = _kindIcon[event.kind] ?? Icons.circle_outlined;
    final hasPayload = event.payload != null && event.payload!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: hasPayload ? () => _showPayloadSheet(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPayload)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '事件详情',
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: '复制',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: pretty));
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      toast.success(message: '已复制到剪贴板');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    pretty,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
