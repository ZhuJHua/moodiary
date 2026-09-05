import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/application/auto_sync_watcher.dart';
import 'package:moodiary_sync/src/application/sync_controller.dart';
import 'package:moodiary_sync/src/application/sync_log_runs.dart';
import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/application/sync_stats_controller.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/presentation/widget/sync_key_guard.dart';
import 'package:moodiary_sync/src/presentation/widget/sync_labels.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

/// 同步控制台：上半是状态面板（连接 · 状态 · 本地计数 · 自动同步 · 立即同步），
/// 下半是日志——一次同步一行（[groupSyncRuns]），点一行看逐条事件。AppBar 的同步
/// 按钮直接进这一页，原来的状态弹窗已并入面板。
///
/// 状态来自 [SyncRunner.status]（手动与自动同源）；日志默认今天并实时追加，可按
/// [SyncLogger] 的按天 jsonl 切换历史日期（保留 7 天，历史视图不追加实时事件）。
class SyncConsolePage extends ConsumerStatefulWidget {
  const SyncConsolePage({super.key});

  @override
  ConsumerState<SyncConsolePage> createState() => _SyncConsolePageState();
}

class _SyncConsolePageState extends ConsumerState<SyncConsolePage> {
  List<SyncEvent> _events = const [];
  StreamSubscription<SyncEvent>? _sub;
  bool _loading = true;
  bool _problemsOnly = false;
  DateTime _selectedDay = .now();

  /// 「已配置」是钥匙串里的事实，异步读一次；从设置页回来重取。
  late Future<bool> _configured = getIt<IRemoteSyncBackend>().isReady();

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
    final today = DateTime.now();
    if (!days.any((d) => _sameDay(d, today))) days.insert(0, today);
    if (!mounted) return;
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

  Future<void> _clearLogs() async {
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

  Future<void> _openSettings() async {
    await const BackupSyncRoute().push(context);
    if (!mounted) return;
    setState(() => _configured = getIt<IRemoteSyncBackend>().isReady());
  }

  Future<void> _syncNow() async {
    final backend = getIt<IRemoteSyncBackend>();
    if (!await ensureSyncKeyReady(
      context: context,
      ref: ref,
      backend: backend,
    )) {
      return;
    }
    await ref.read(syncControllerProvider.notifier).sync(backend);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SyncState>(syncControllerProvider, (prev, next) {
      if (next is SyncSuccess || next is SyncPartial || next is SyncError) {
        ref.invalidate(syncStatsProvider);
      }
    });
    final entries = groupSyncRuns(_events);
    final visible = _problemsOnly
        ? entries.where((e) => e.hasProblem).toList()
        : entries;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.sync.consoleTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.sync.logClear,
            icon: const Icon(LucideIcons.eraser),
            onPressed: _clearLogs,
          ),
          IconButton(
            tooltip: context.l10n.sync.pageTitle,
            icon: const Icon(LucideIcons.slidersHorizontal),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const .fromLTRB(12, 4, 12, 0),
            sliver: SliverToBoxAdapter(
              child: FutureBuilder(
                future: _configured,
                builder: (context, snapshot) => _StatusPanel(
                  configured: snapshot.data ?? false,
                  onSync: _syncNow,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const .fromLTRB(20, 22, 20, 4),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  MInkWell(
                    borderRadius: .circular(8),
                    onTap: _pickDay,
                    child: Padding(
                      padding: const .symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: .min,
                        children: [
                          Text(
                            _viewingToday
                                ? context.l10n.sync.logToday
                                : TimeFormat.isoDate(_selectedDay),
                            style: context
                                .theme
                                .typography
                                .labelSmall
                                .onSurfaceVariant
                                .copyWith(letterSpacing: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            LucideIcons.chevronDown,
                            size: 14,
                            color: context.theme.colors.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _Pill(
                    label: context.l10n.sync.logFilterProblems,
                    selected: _problemsOnly,
                    onTap: () => setState(() => _problemsOnly = !_problemsOnly),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visible.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: _Empty())
          else
            SliverPadding(
              padding: .fromLTRB(12, 0, 12, 24 + context.safeBottom),
              sliver: SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) => switch (visible[index]) {
                  final SyncLogRun run => _RunLine(run: run),
                  final SyncLogSingle single => _SingleLine(
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

// ─────────────────────── 状态面板 ───────────────────────

/// 四段：连接指示灯与后端一行 / 状态标题与时刻 / 本地计数（远端不一致才标）/
/// 自动同步与下次轮询，末尾一颗按钮。「未配置」与「连不上」是仅有的两个要用户
/// 离开去做点什么的状态，标题走 error 色。
class _StatusPanel extends ConsumerStatefulWidget {
  final bool configured;
  final Future<void> Function() onSync;

  const _StatusPanel({required this.configured, required this.onSync});

  @override
  ConsumerState<_StatusPanel> createState() => _StatusPanelState();
}

class _StatusPanelState extends ConsumerState<_StatusPanel> {
  /// 倒计时每秒走一格。
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(syncControllerProvider);
    final stats = ref.watch(syncStatsProvider);
    final encrypted = ref
        .watch(syncDekControllerProvider)
        .maybeWhen(
          data: (key) => key != null && key.isNotEmpty,
          orElse: () => false,
        );
    final runner = getIt<SyncRunner>();
    final watcher = getIt<AutoSyncWatcher>();
    return ListenableBuilder(
      listenable: .merge([
        runner.status,
        getIt<SyncDirtyTracker>().listenable,
        getIt<SyncCancellation>().listenable,
        MoodiaryKVs.lastSyncTime.getNotifier(),
        MoodiaryKVs.autoSync.getNotifier(),
        MoodiaryKVs.syncPollInterval.getNotifier(),
        watcher.nextPollAt,
      ]),
      builder: (context, _) => _build(
        context,
        state: state,
        status: runner.status.value,
        stats: stats,
        encrypted: encrypted,
        pendingLocal: getIt<SyncDirtyTracker>().listenable.value.length,
        stopping: getIt<SyncCancellation>().listenable.value,
        nextPollAt: watcher.nextPollAt.value,
      ),
    );
  }

  Widget _build(
    BuildContext context, {
    required SyncState state,
    required SyncStatus status,
    required AsyncValue<SyncStats> stats,
    required bool encrypted,
    required int pendingLocal,
    required bool stopping,
    required DateTime? nextPollAt,
  }) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final backend = getIt<IRemoteSyncBackend>();
    final running = state is SyncRunning;
    final configured = widget.configured;
    final bad = configured && status.health.isBad;

    // 指示灯：绿 = 可达，红 = 坏了，灰 = 未知 / 未配置。
    final led = !configured
        ? scheme.outline
        : bad
        ? scheme.error
        : status.health == .reachable
        ? context.theme.success
        : scheme.outline;
    final micro = [
      backend.type.label,
      if (configured) ?syncHealthShort(l10n, status.health),
      encrypted ? l10n.sync.encrypted : l10n.sync.notEncrypted,
    ].join(' · ');

    final (title, sub, warn) = _headline(
      l10n,
      state: state,
      status: status,
      configured: configured,
      backendName: backend.type.label,
      pendingLocal: pendingLocal,
    );

    final value = switch (stats) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final autoOn = MoodiaryKVs.autoSync.get() == true;
    final remaining = nextPollAt?.difference(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppBorderRadius.largeBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .fromLTRB(18, 18, 18, 16),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: .circle,
                              color: led,
                              boxShadow: [
                                BoxShadow(
                                  color: led.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              micro,
                              maxLines: 1,
                              overflow: .ellipsis,
                              style: typography.labelSmall.onSurfaceVariant
                                  .copyWith(letterSpacing: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: warn
                            ? typography.headlineSmall.error
                            : typography.headlineSmall.onSurface,
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: .ellipsis,
                          style: typography.bodySmall.outline.copyWith(
                            fontFeatures: const [.tabularFigures()],
                          ),
                        ),
                      ],
                      if (running) ...[
                        const SizedBox(height: 10),
                        const ClipRRect(
                          borderRadius: .all(.circular(2)),
                          // ignore: deprecated_member_use
                          child: LinearProgressIndicator(year2023: false),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const .only(top: 10),
                  child: _ProbeButton(
                    icon: backend.type == .webdav
                        ? LucideIcons.cloud
                        : LucideIcons.database,
                    enabled: configured && !running,
                    onProbed: () => ref.invalidate(syncStatsProvider),
                  ),
                ),
              ],
            ),
          ),
          _hair(context),
          Padding(
            padding: const .fromLTRB(10, 14, 10, 14),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                Expanded(
                  child: _Counter(
                    label: l10n.sync.rowDiary,
                    local: value?.localDiaries,
                    remote: value?.remoteDiaries,
                  ),
                ),
                _divider(context),
                Expanded(
                  child: _Counter(
                    label: l10n.sync.rowCategory,
                    local: value?.localCategories,
                    remote: value?.remoteCategories,
                  ),
                ),
                _divider(context),
                Expanded(
                  child: _Counter(
                    label: l10n.sync.rowMedia,
                    local: value?.localMedia,
                    remote: value?.remoteMedia,
                  ),
                ),
              ],
            ),
          ),
          if (!bad)
            if (value?.remoteError case final error?)
              Padding(
                padding: const .fromLTRB(18, 0, 18, 12),
                child: Text(
                  error,
                  maxLines: 2,
                  overflow: .ellipsis,
                  style: typography.bodySmall.error,
                ),
              ),
          _hair(context),
          Padding(
            padding: const .fromLTRB(18, 12, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    autoOn
                        ? l10n.sync.autoSyncEvery(
                            interval: _fmtInterval(
                              l10n,
                              MoodiaryKVs.syncPollInterval.get() ?? 30,
                            ),
                          )
                        : l10n.sync.autoSyncOff,
                    style: typography.bodySmall.onSurfaceVariant,
                  ),
                ),
                if (autoOn && remaining != null && !running)
                  Text(
                    _fmtCountdown(l10n, remaining),
                    style: typography.bodySmall.outline.copyWith(
                      fontFeatures: const [.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const .fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: running
                    ? (stopping
                          ? null
                          : () => ref
                                .read(syncControllerProvider.notifier)
                                .stop())
                    : configured
                    ? widget.onSync
                    : null,
                style: FilledButton.styleFrom(
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppBorderRadius.mediumBorderRadius,
                  ),
                ),
                child: Text(
                  running
                      ? (stopping ? l10n.sync.stopping : l10n.sync.stop)
                      : l10n.sync.syncNow,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 标题 / 副行 / 是否 error 色。优先级：正在跑 → 未配置 → 连不上 → 上次失败或
  /// 未完成 → 同步过 → 从未同步。
  (String, String?, bool) _headline(
    Translations l10n, {
    required SyncState state,
    required SyncStatus status,
    required bool configured,
    required String backendName,
    required int pendingLocal,
  }) {
    if (state case SyncRunning(:final label)) {
      final trigger = status.running?.trigger;
      return (
        l10n.sync.statusRunning,
        trigger == null || trigger == .manual
            ? label
            : '$label · ${syncTriggerLabel(l10n, trigger)}',
        false,
      );
    }
    if (!configured) {
      return (l10n.sync.statusNoBackend, l10n.sync.statusNoBackendDetail, true);
    }
    final pending = pendingLocal > 0
        ? l10n.sync.pendingLocal(count: pendingLocal)
        : null;
    final healthTitle = syncHealthTitle(
      l10n,
      status.health,
      backend: backendName,
    );
    if (healthTitle != null) {
      // 明细（原始错误串）不上面板：标题已经说了病因，原文在日志行的 payload 里。
      final since = status.healthSince;
      final lastOk = MoodiaryKVs.lastSyncTime.get() ?? 0;
      return (
        healthTitle,
        [
          if (since != null)
            l10n.sync.healthSince(time: TimeFormat.clock(since)),
          if (lastOk > 0)
            l10n.sync.lastSuccess(
              time: TimeFormat.clock(.fromMillisecondsSinceEpoch(lastOk)),
            ),
          ?pending,
        ].join(' · '),
        true,
      );
    }
    final last = status.last;
    if (last != null) {
      final stamp =
          '${TimeFormat.timeHms(last.at)} · ${syncTriggerLabel(l10n, last.trigger)}';
      switch (last.kind) {
        case .failed:
          return (l10n.sync.statusFailed, '${last.message}\n$stamp', true);
        case .partial || .stopped:
          return (l10n.sync.statusPartial, '${last.message}\n$stamp', true);
        case .upToDate || .changed:
          return (l10n.sync.statusSynced, [stamp, ?pending].join(' · '), false);
      }
    }
    final millis = MoodiaryKVs.lastSyncTime.get() ?? 0;
    if (millis > 0) {
      return (
        l10n.sync.statusSynced,
        [
          TimeFormat.listDateTime(.fromMillisecondsSinceEpoch(millis)),
          ?pending,
        ].join(' · '),
        false,
      );
    }
    return (l10n.sync.statusNever, pending, false);
  }

  static String _fmtInterval(Translations l10n, int seconds) {
    if (seconds < 60) return l10n.sync.seconds(count: seconds);
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0
        ? l10n.sync.minutes(count: m)
        : l10n.sync.minutesSeconds(minutes: m, seconds: s);
  }

  static String _fmtCountdown(Translations l10n, Duration remaining) {
    final total = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
    final m = total ~/ 60;
    final s = total % 60;
    return m == 0
        ? l10n.sync.nextPollInSeconds(seconds: s)
        : l10n.sync.nextPollIn(minutes: m, seconds: s);
  }

  Widget _hair(BuildContext context) => Padding(
    padding: const .symmetric(horizontal: 18),
    child: Divider(
      height: 1,
      thickness: 0,
      color: context.theme.colors.outlineVariant,
    ),
  );

  Widget _divider(BuildContext context) => Container(
    width: 1,
    height: 40,
    color: context.theme.colors.outlineVariant,
  );
}

/// 面板右上角的后端图标同时是「测试连接」：点一下重新探测，转圈期间禁点；
/// 结果直接写进健康态（指示灯、标题随之变），不弹 toast。
class _ProbeButton extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onProbed;

  const _ProbeButton({
    required this.icon,
    required this.enabled,
    required this.onProbed,
  });

  @override
  State<_ProbeButton> createState() => _ProbeButtonState();
}

class _ProbeButtonState extends State<_ProbeButton> {
  bool _busy = false;

  Future<void> _probe() async {
    setState(() => _busy = true);
    try {
      await getIt<SyncRunner>().testConnection();
    } on SyncException {
      // 健康态已由 runner 更新，面板自己会红。
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onProbed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return IconButton(
      tooltip: context.l10n.sync.testConnection,
      onPressed: widget.enabled && !_busy ? _probe : null,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(widget.icon, size: 22, color: scheme.outline),
    );
  }
}

/// 一格计数：标签、本地数；远端不一致时旁边一小行 tertiary 色的「远端 N」。
class _Counter extends StatelessWidget {
  final String label;
  final int? local;
  final int? remote;

  const _Counter({
    required this.label,
    required this.local,
    required this.remote,
  });

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;
    final differs = local != null && remote != null && local != remote;
    return Padding(
      padding: const .symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            label,
            style: typography.labelSmall.onSurfaceVariant.copyWith(
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: .baseline,
            textBaseline: .alphabetic,
            children: [
              Text(
                local?.toString() ?? '—',
                style: typography.titleLarge.emphasized.onSurface.copyWith(
                  fontFeatures: const [.tabularFigures()],
                ),
              ),
              if (differs) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    context.l10n.sync.remoteCount(count: remote!),
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: typography.labelSmall.tertiary.copyWith(
                      fontFeatures: const [.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    return MInkWell(
      borderRadius: .circular(999),
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const .symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? scheme.surfaceContainerHighest : null,
          border: selected ? null : Border.all(color: scheme.outlineVariant),
          borderRadius: .circular(999),
        ),
        alignment: .center,
        child: Text(
          label,
          style: selected
              ? typography.labelMedium.onSurface
              : typography.labelMedium.onSurfaceVariant,
        ),
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

// ─────────────────────── 日志行 ───────────────────────

/// 一行：时间 58 · 图标 16 · 标题 · 结果 · 耗时 48。段头与散落事件同一网格。
class _Line extends StatelessWidget {
  final DateTime at;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String result;
  final Color? resultColor;
  final String elapsed;
  final VoidCallback? onTap;

  const _Line({
    required this.at,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.result = '',
    this.resultColor,
    this.elapsed = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    return MInkWell(
      borderRadius: .circular(8),
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const .symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: scheme.surfaceContainer, width: 1),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Text(
                TimeFormat.timeHms(at),
                style: typography.bodySmall.outline.copyWith(
                  fontFeatures: const [.tabularFigures()],
                ),
              ),
            ),
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: .ellipsis,
                style: typography.bodyMedium.onSurface.copyWith(
                  color: titleColor,
                ),
              ),
            ),
            if (result.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                result,
                style: typography.labelSmall.outline.copyWith(
                  color: resultColor,
                  fontFeatures: const [.tabularFigures()],
                ),
              ),
            ],
            SizedBox(
              width: 48,
              child: Text(
                elapsed,
                textAlign: .end,
                style: typography.labelSmall.outline.copyWith(
                  color: scheme.outline.withValues(alpha: 0.7),
                  fontFeatures: const [.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunLine extends StatelessWidget {
  final SyncLogRun run;

  const _RunLine({required this.run});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    final (result, color) = _outcome(context, run);
    final failed = run.outcome == .failed;
    return _Line(
      at: run.at,
      icon: _runIcon(run),
      iconColor: failed
          ? scheme.error
          : run.hasProblem
          ? scheme.tertiary
          : (run.outcome == .changed || run.open)
          ? scheme.primary
          : scheme.outline,
      title: _runHeadline(l10n, run),
      titleColor: failed ? scheme.error : null,
      result: result,
      resultColor: color,
      elapsed: run.open ? '' : syncElapsedLabel(l10n, run.elapsed),
      onTap: () => _showRunSheet(context),
    );
  }

  void _showRunSheet(BuildContext context) {
    final l10n = context.l10n;
    MSheet.show<void>(
      context,
      builder: (ctx) => MSheetScaffold<void>(
        title: _runHeadline(l10n, run),
        subtitle: [
          TimeFormat.timeHms(run.at),
          if (!run.open) syncElapsedLabel(l10n, run.elapsed),
          _outcome(ctx, run).$1,
        ].where((s) => s.isNotEmpty).join(' · '),
        icon: _runIcon(run),
        actions: [MAction(label: ctx.l10n.common.ok, isPrimary: true)],
        child: Column(
          crossAxisAlignment: .stretch,
          mainAxisSize: .min,
          children: [
            for (final entry in foldSameKind(run.events))
              switch (entry) {
                final SyncEvent e => _EventRow(event: e),
                final List<SyncEvent> group => _FoldTile(events: group),
                _ => const SizedBox.shrink(),
              },
          ],
        ),
      ),
    );
  }
}

/// 段头结果文案与颜色：已是最新 / ↑ 1 · ↓ 2 · 媒体 3 / 未完成 · n / 已停止 / 失败 / 进行中。
(String, Color?) _outcome(BuildContext context, SyncLogRun run) {
  final l10n = context.l10n;
  final scheme = context.theme.colors;
  return switch (run.outcome) {
    null => (l10n.sync.statusRunning, scheme.primary),
    .failed => (l10n.sync.logRunFailed, scheme.error),
    .partial => (
      '${l10n.sync.logRunPartial} · ${run.failedCount}',
      scheme.tertiary,
    ),
    .stopped => (l10n.sync.logRunStopped, scheme.tertiary),
    .upToDate => (l10n.sync.logRunUpToDate, null),
    .changed => (
      [
        if (run.pushedCount > 0) '↑ ${run.pushedCount}',
        if (run.pulledCount > 0) '↓ ${run.pulledCount}',
        if (run.mediaCount > 0) l10n.sync.summaryMedia(count: run.mediaCount),
      ].join(' · '),
      scheme.primary,
    ),
  };
}

String _runHeadline(Translations l10n, SyncLogRun run) {
  final direction = run.neverStarted
      ? _kindLabel(l10n, .lockAcquire)
      : run.bidirectional
      ? l10n.sync.directionSync
      : (_directionLabel(l10n, run.directions.firstOrNull) ??
            _kindLabel(l10n, .syncStart));
  return [direction, ?syncTriggerLabelOf(l10n, run.trigger)].join(' · ');
}

IconData _runIcon(SyncLogRun run) => run.neverStarted
    ? LucideIcons.lock
    : run.bidirectional
    ? LucideIcons.refreshCw
    : switch (run.directions.firstOrNull) {
        'push' => LucideIcons.cloudUpload,
        'pull' || 'restore' => LucideIcons.cloudDownload,
        're-cipher' => LucideIcons.refreshCcw,
        _ => LucideIcons.refreshCw,
      };

/// 段外的散落事件：健康态切换（payload 带 health）显示成「连接 · 无法连接」，
/// 其余按 kind + reason。
class _SingleLine extends StatelessWidget {
  final SyncEvent event;

  const _SingleLine({required this.event});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    final color = _levelColor(context, event.level);
    final health = _healthOf(event);
    final hasPayload = event.payload != null && event.payload!.isNotEmpty;
    if (health != null) {
      final bad = health.isBad;
      final tone = bad ? scheme.error : context.theme.success;
      return _Line(
        at: event.at,
        icon: bad ? LucideIcons.cloudOff : LucideIcons.cloud,
        iconColor: tone,
        title: l10n.sync.logHealth,
        titleColor: bad ? scheme.error : null,
        result: syncHealthShort(l10n, health) ?? '',
        resultColor: tone,
        onTap: hasPayload ? () => _showPayloadSheet(context, event) : null,
      );
    }
    return _Line(
      at: event.at,
      icon: _kindIcon(event.kind),
      iconColor: color,
      title: _kindLabel(l10n, event.kind),
      titleColor: event.level == .error ? scheme.error : null,
      result: _reasonLabel(l10n, event.reason) ?? '',
      resultColor: event.level == .info ? null : color,
      onTap: hasPayload ? () => _showPayloadSheet(context, event) : null,
    );
  }

  static SyncHealth? _healthOf(SyncEvent event) {
    final name = event.payload?['health'];
    if (name is! String) return null;
    for (final h in SyncHealth.values) {
      if (h.name == name) return h;
    }
    return null;
  }
}

// ─────────────────────── 运行详情里的事件行 ───────────────────────

class _EventRow extends StatelessWidget {
  final SyncEvent event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final hasPayload = event.payload != null && event.payload!.isNotEmpty;
    final isError = event.level == .error;
    final line = [
      _kindLabel(l10n, event.kind),
      ?_reasonLabel(l10n, event.reason),
      ?_subjectOf(l10n, event),
    ].where((s) => s.isNotEmpty).join(' · ');
    return MInkWell(
      borderRadius: .circular(8),
      onTap: hasPayload ? () => _showPayloadSheet(context, event) : null,
      child: Padding(
        padding: const .symmetric(horizontal: 4, vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Text(
                TimeFormat.timeHms(event.at),
                style: typography.bodySmall.outline.copyWith(
                  fontFeatures: const [.tabularFigures()],
                ),
              ),
            ),
            Icon(
              _kindIcon(event.kind),
              size: 16,
              color: _levelColor(context, event.level),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                line,
                maxLines: 1,
                overflow: .ellipsis,
                style: isError
                    ? typography.bodyMedium.error
                    : typography.bodyMedium.onSurface,
              ),
            ),
            if (hasPayload)
              Icon(LucideIcons.chevronRight, size: 16, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

/// 详情里连续同 kind 的折叠组（≥2 条）。
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
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final events = widget.events;
    final kind = events.first.kind;
    final worst = events.fold<SyncEventLevel>(
      .info,
      (acc, e) => e.level.index > acc.index ? e.level : acc,
    );
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
        MInkWell(
          borderRadius: .circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const .symmetric(horizontal: 4, vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    TimeFormat.timeHms(events.first.at),
                    style: typography.bodySmall.outline.copyWith(
                      fontFeatures: const [.tabularFigures()],
                    ),
                  ),
                ),
                Icon(
                  _kindIcon(kind),
                  size: 16,
                  color: _levelColor(context, worst),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: worst == .error
                        ? typography.bodyMedium.error
                        : typography.bodyMedium.onSurface,
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          for (final e in events) _EventRow(event: e),
      ],
    );
  }
}

void _showPayloadSheet(BuildContext context, SyncEvent event) {
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

// ─────────────────────── 文案 / 图标映射 ───────────────────────

Color _levelColor(BuildContext context, SyncEventLevel level) {
  final scheme = context.theme.colors;
  return switch (level) {
    .error => scheme.error,
    .warn => scheme.tertiary,
    .info => scheme.onSurfaceVariant,
  };
}

String? _directionLabel(Translations l10n, String? direction) =>
    switch (direction) {
      'pull' => l10n.sync.directionPull,
      'push' => l10n.sync.directionPush,
      'restore' => l10n.sync.directionRestore,
      're-cipher' => l10n.sync.directionReCipher,
      _ => null,
    };

/// kind → 图标 / 文案，都用 switch 而不是 Map：加了新 kind 忘了配就编译报错。
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
  .placeUpload => LucideIcons.upload,
  .placeDownload => LucideIcons.download,
  .placeSkip => LucideIcons.skipForward,
  .placeTombstonePush => LucideIcons.eraser,
  .placeTombstonePull => LucideIcons.trash2,
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
  .placeUpload => l10n.sync.kindPlaceUpload,
  .placeDownload => l10n.sync.kindPlaceDownload,
  .placeSkip => l10n.sync.kindPlaceSkip,
  .placeTombstonePush => l10n.sync.kindPlaceTombstonePush,
  .placeTombstonePull => l10n.sync.kindPlaceTombstonePull,
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

/// 从 payload 提取事件的一行摘要（方向 / 条数 / 标题 / 文件名…）。取不到返回 null。
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
    .placeUpload ||
    .placeDownload ||
    .placeSkip ||
    .placeTombstonePush ||
    .placeTombstonePull => str('placeName') ?? str('placeId') ?? str('key'),
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

/// [SyncEventReason] 的展示文案。
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
