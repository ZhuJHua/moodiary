import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/application/sync_controller.dart';
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

/// 「同步状态」底部弹窗：配置标签 / 当前状态与进度 / 上次运行 / 待上传 / 数据概览 /
/// 立即同步（同步中可停止；连不上时是重试 + 检查配置）/ 查看日志入口。
/// 状态来自 [SyncRunner.status]（手动与自动同源），日志本身见 [SyncLogPage]。
Future<void> showSyncStatusSheet(BuildContext context) async {
  // 「已配置」是钥匙串里的事实，进弹窗前读好；弹窗开着时配置不会变（改配置在另一张弹窗）。
  final configured = await getIt<IRemoteSyncBackend>().isReady();
  if (!context.mounted) return;
  final result = await MSheet.show<String>(
    context,
    builder: (_) => _SyncStatusSheet(configured: configured),
  );
  // 等弹窗收起后再用外层 context 导航：弹窗自己的 context pop 后已卸载。
  if (!context.mounted) return;
  switch (result) {
    case _SyncStatusSheet.resultViewLog:
      const SyncLogRoute().push(context);
    case _SyncStatusSheet.resultOpenSettings:
      const BackupSyncRoute().push(context);
  }
}

class _SyncStatusSheet extends ConsumerStatefulWidget {
  static const String resultViewLog = 'viewLog';
  static const String resultOpenSettings = 'openSettings';

  const _SyncStatusSheet({required this.configured});

  final bool configured;

  @override
  ConsumerState<_SyncStatusSheet> createState() => _SyncStatusSheetState();
}

class _SyncStatusSheetState extends ConsumerState<_SyncStatusSheet> {
  /// 本轮同步（自最近一次 syncStart 起）的实时计数。
  int _uploaded = 0;
  int _downloaded = 0;
  int _media = 0;
  int _failed = 0;
  StreamSubscription<SyncEvent>? _sub;

  @override
  void initState() {
    super.initState();
    // 卡片可能在同步中途打开：先从内存 ring buffer 回放本会话事件补齐计数，再订阅后续。
    for (final event in getIt<SyncLogger>().recent) {
      _applyCounter(event);
    }
    _sub = getIt<SyncLogger>().events.listen((event) {
      if (!mounted) return;
      setState(() => _applyCounter(event));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _applyCounter(SyncEvent event) {
    switch (event.kind) {
      case .syncStart:
        _uploaded = 0;
        _downloaded = 0;
        _media = 0;
        _failed = 0;
      case .diaryUpload || .categoryUpload:
        if (event.level != .error) _uploaded++;
      case .diaryDownload || .categoryDownload:
        if (event.level != .error) _downloaded++;
      case .mediaUpload || .mediaDownload:
        if (event.level != .error) _media++;
      default:
        break;
    }
    // 失败看 level 而不是 kind：失败事件沿用操作 kind（红色 diaryUpload =
    // 「上传日记失败」），不再有专门的 error kind 可数。syncEnd 除外——它是整轮的
    // 汇总（异常中止也走 error），计进来会让「失败条目数」凭空多一。
    if (event.level == .error && event.kind != .syncEnd) _failed++;
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

    final state = ref.watch(syncControllerProvider);
    final stats = ref.watch(syncStatsProvider);
    final backend = getIt<IRemoteSyncBackend>();
    final encryption = ref
        .watch(syncDekControllerProvider)
        .maybeWhen(
          data: (key) => key != null && key.isNotEmpty,
          orElse: () => false,
        );

    return ValueListenableBuilder(
      valueListenable: getIt<SyncRunner>().status,
      builder: (context, status, _) => ValueListenableBuilder(
        valueListenable: getIt<SyncDirtyTracker>().listenable,
        builder: (context, dirty, _) => ValueListenableBuilder(
          valueListenable: getIt<SyncCancellation>().listenable,
          builder: (context, stopping, _) => _buildSheet(
            context,
            state: state,
            status: status,
            stats: stats,
            backend: backend,
            encryption: encryption,
            pendingLocal: dirty.length,
            stopping: stopping,
          ),
        ),
      ),
    );
  }

  MSheetScaffold<String> _buildSheet(
    BuildContext context, {
    required SyncState state,
    required SyncStatus status,
    required AsyncValue<SyncStats> stats,
    required IRemoteSyncBackend backend,
    required bool encryption,
    required int pendingLocal,
    required bool stopping,
  }) {
    final running = state is SyncRunning;
    final broken = widget.configured && status.health.isBad;

    // 「立即同步 / 停止同步」自行接管点击：同步跑起来后弹窗要留着看进度，不能关。
    final actions = <MAction<String>>[
      MAction(
        label: context.l10n.sync.viewLog,
        value: _SyncStatusSheet.resultViewLog,
      ),
      if (running)
        MAction(
          label: stopping ? context.l10n.sync.stopping : context.l10n.sync.stop,
          isPrimary: true,
          enabled: !stopping,
          onPressed: () => ref.read(syncControllerProvider.notifier).stop(),
        )
      else if (broken) ...[
        MAction(
          label: context.l10n.sync.checkConfig,
          value: _SyncStatusSheet.resultOpenSettings,
        ),
        MAction(
          label: context.l10n.sync.retry,
          isPrimary: true,
          onPressed: _syncNow,
        ),
      ] else
        MAction(
          label: context.l10n.sync.syncNow,
          isPrimary: true,
          enabled: widget.configured,
          onPressed: _syncNow,
        ),
    ];

    final card = _StateCard(
      state: state,
      status: status,
      configured: widget.configured,
      stats: stats,
      backendName: backend.type.label,
      uploaded: _uploaded,
      downloaded: _downloaded,
      media: _media,
      failed: _failed,
    );

    return MSheetScaffold<String>(
      title: context.l10n.sync.statusTitle,
      // 后端与加密是背景事实不是状态，降到副标题，别跟「同步失败」抢同一级视觉。
      subtitle: context.l10n.sync.statusSubtitle(
        backend: backend.type.label,
        encryption: encryption
            ? context.l10n.sync.encrypted
            : context.l10n.sync.notEncrypted,
      ),
      icon: backend.type == .webdav ? LucideIcons.cloud : LucideIcons.database,
      actions: actions,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          card,
          // 卡片没在讲上次结果时，用一行小字交代「上次运行」——这是「自动同步到底
          // 跑没跑」唯一直接的证据。
          if (!running && !card.showsOutcome && status.last != null)
            _LastRunLine(outcome: status.last!),
          if (!running && pendingLocal > 0)
            _Hint(text: context.l10n.sync.pendingLocal(count: pendingLocal)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: MFormSection(context.l10n.sync.overview)),
              IconButton(
                tooltip: context.l10n.sync.overviewRefresh,
                icon: const Icon(LucideIcons.rotateCw),
                iconSize: 16,
                visualDensity: .compact,
                onPressed: () => ref.invalidate(syncStatsProvider),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _StatsTable(stats: stats),
        ],
      ),
    );
  }
}

/// 状态卡：一行结论 + 一行佐证，是这张弹窗唯一的主视觉。优先级从上往下第一个命中：
/// 正在跑 → 未配置 → 连接健康坏了 → 手动同步的结果 → 自动同步的失败 / 未完成 →
/// 同步过 → 从未同步。「未配置」与「连不上」是仅有的两个需要用户离开去做点什么的
/// 状态，走 error 底纹。
class _StateCard extends StatelessWidget {
  final SyncState state;
  final SyncStatus status;
  final bool configured;
  final AsyncValue<SyncStats> stats;
  final String backendName;
  final int uploaded;
  final int downloaded;
  final int media;
  final int failed;

  const _StateCard({
    required this.state,
    required this.status,
    required this.configured,
    required this.stats,
    required this.backendName,
    required this.uploaded,
    required this.downloaded,
    required this.media,
    required this.failed,
  });

  /// 卡片本身已经在讲一次运行的结果（弹窗据此决定要不要再补「上次运行」那行）。
  bool get showsOutcome {
    if (state is SyncSuccess || state is SyncPartial || state is SyncError) {
      return true;
    }
    if (!configured || status.health.isBad) return false;
    return switch (status.last?.kind) {
      .failed || .partial || .stopped => true,
      _ => false,
    };
  }

  /// 从未同步过时，若远端已有内容就把「有多少可拉」说出来。
  String? _pendingHint() {
    final remote = switch (stats) {
      AsyncData(:final value) => value.remoteDiaries,
      _ => null,
    };
    if (remote == null || remote == 0) return null;
    return l10n.sync.pendingPull(count: remote);
  }

  @override
  Widget build(BuildContext context) {
    if (state case SyncRunning(:final label)) {
      final trigger = status.running?.trigger;
      return _Shell(
        warn: false,
        child: Column(
          crossAxisAlignment: .stretch,
          mainAxisSize: .min,
          children: [
            const ClipRRect(
              borderRadius: .all(.circular(2)),
              // year2023: false → 2024 版 M3 进度条；该参数为迁移期 deprecated 标记。
              // ignore: deprecated_member_use
              child: LinearProgressIndicator(year2023: false),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: context.theme.typography.titleSmall.emphasized.onSurface,
            ),
            if (trigger != null && trigger != .manual)
              Padding(
                padding: const .only(top: 2),
                child: Text(
                  syncTriggerLabel(context.l10n, trigger),
                  style: context.theme.typography.bodySmall.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Counter(icon: LucideIcons.arrowUp, value: uploaded),
                _Counter(icon: LucideIcons.arrowDown, value: downloaded),
                _Counter(icon: LucideIcons.image, value: media),
                // 没有失败时不占位 —— 常驻的「失败 0」只会让人多看一眼。
                if (failed > 0)
                  _Counter(
                    icon: LucideIcons.triangleAlert,
                    value: failed,
                    bad: true,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    if (!configured) {
      return _Line(
        icon: LucideIcons.unplug,
        title: l10n.sync.statusNoBackend,
        detail: l10n.sync.statusNoBackendDetail,
        warn: true,
      );
    }

    final healthTitle = syncHealthTitle(
      context.l10n,
      status.health,
      backend: backendName,
    );
    if (healthTitle != null) {
      final since = status.healthSince;
      return _Line(
        icon: status.health == .keyConflict
            ? LucideIcons.lockKeyhole
            : LucideIcons.cloudOff,
        title: healthTitle,
        detail: [
          if (since != null)
            l10n.sync.healthSince(time: TimeFormat.listDateTime(since)),
          ?status.healthDetail,
        ].join(' · '),
        warn: true,
      );
    }

    return switch (state) {
      SyncSuccess(:final message, :final upToDate) => _Line(
        icon: LucideIcons.circleCheck,
        title: upToDate ? l10n.sync.statusUpToDate : l10n.sync.statusDone,
        detail: _manualDetail(message),
      ),
      // 有失败条目 / 被停止：绝不能和「同步完成」长一个样——引擎正因为这两种情况
      // 不推进「上次同步时间」，用户却会据此以为云端已有完整副本。
      SyncPartial(:final message) => _Line(
        icon: LucideIcons.triangleAlert,
        title: l10n.sync.statusPartial,
        detail: _manualDetail(message),
        warn: true,
      ),
      SyncError(:final message) => _Line(
        icon: LucideIcons.triangleAlert,
        title: l10n.sync.statusFailed,
        detail: _manualDetail(message),
        warn: true,
      ),
      _ => _idle(context),
    };
  }

  /// 手动同步的结果带上时刻与耗时：空转一次只要几十毫秒，进度条一闪而过，
  /// 卡片文案又与上一次相同，用户看不出「刚才那下按到了」，就会再按。
  String _manualDetail(String message) {
    final last = status.last;
    if (last == null || last.trigger != .manual) return message;
    return [
      message,
      '${TimeFormat.timeHms(last.at)} · ${syncElapsedLabel(l10n, last.elapsed)}',
    ].join('\n');
  }

  Widget _idle(BuildContext context) {
    // 自动同步的失败 / 未完成：手动路径之外的结果只存在 runner 里。
    final last = status.last;
    if (last != null) {
      switch (last.kind) {
        case .failed:
          return _Line(
            icon: LucideIcons.triangleAlert,
            title: l10n.sync.statusFailed,
            detail: _withTime(last),
            warn: true,
          );
        case .partial || .stopped:
          return _Line(
            icon: LucideIcons.triangleAlert,
            title: l10n.sync.statusPartial,
            detail: _withTime(last),
            warn: true,
          );
        case .upToDate || .changed:
          break;
      }
    }
    return ValueListenableBuilder(
      valueListenable: MoodiaryKVs.lastSyncTime.getNotifier(),
      builder: (context, millis, _) => millis > 0
          ? _Line(
              icon: LucideIcons.circleCheck,
              // 只说「同步过」这个事实：两侧条目数相等也不代表内容一致，
              // 差异由下面的对照表用颜色说。
              title: l10n.sync.statusSynced,
              detail:
                  l10n.sync.statusLastSync +
                  TimeFormat.listDateTime(.fromMillisecondsSinceEpoch(millis)),
            )
          : _Line(
              icon: LucideIcons.clock,
              title: l10n.sync.statusNever,
              detail: _pendingHint(),
            ),
    );
  }

  String _withTime(SyncOutcome outcome) => [
    outcome.message,
    '${syncTriggerLabel(l10n, outcome.trigger)} · ${TimeFormat.timeHms(outcome.at)}',
  ].join('\n');
}

/// 「上次运行 · 自动 · 14:32:05 · 1.3 秒 · 没有需要同步的内容」。
class _LastRunLine extends StatelessWidget {
  final SyncOutcome outcome;

  const _LastRunLine({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Hint(
      text: [
        l10n.sync.statusLastRun,
        syncTriggerLabel(l10n, outcome.trigger),
        TimeFormat.timeHms(outcome.at),
        syncElapsedLabel(l10n, outcome.elapsed),
        outcome.message,
      ].join(' · '),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(4, 8, 4, 0),
    child: Text(
      text,
      maxLines: 2,
      overflow: .ellipsis,
      style: context.theme.typography.bodySmall.onSurfaceVariant.copyWith(
        fontFeatures: const [.tabularFigures()],
      ),
    ),
  );
}

class _Shell extends StatelessWidget {
  final bool warn;
  final Widget child;

  const _Shell({required this.warn, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Container(
      padding: const .fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: warn
            ? scheme.error.withValues(alpha: 0.10)
            : scheme.surfaceContainerHighest,
        borderRadius: AppBorderRadius.mediumBorderRadius,
      ),
      child: child,
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? detail;
  final bool warn;

  const _Line({
    required this.icon,
    required this.title,
    this.detail,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final accent = warn ? scheme.error : scheme.primary;
    final detail = this.detail;
    return _Shell(
      warn: warn,
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                Text(
                  title,
                  style: warn
                      ? typography.titleSmall.emphasized.error
                      : typography.titleSmall.emphasized.onSurface,
                ),
                if (detail != null && detail.isNotEmpty)
                  Padding(
                    padding: const .only(top: 2),
                    child: Text(
                      detail,
                      maxLines: 3,
                      overflow: .ellipsis,
                      style: typography.bodySmall.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final IconData icon;
  final int value;
  final bool bad;

  const _Counter({required this.icon, required this.value, this.bad = false});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final style = bad
        ? context.theme.typography.labelMedium.error
        : context.theme.typography.labelMedium.onSurfaceVariant;
    return Container(
      padding: const .symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bad
            ? scheme.error.withValues(alpha: 0.12)
            : scheme.surfaceContainerHigh,
        borderRadius: const .all(.circular(999)),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(icon, size: 12, color: style.color),
          const SizedBox(width: 5),
          Text(
            '$value',
            style: style.copyWith(fontFeatures: const [.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

/// 本地 / 远端两列对照。两侧对不上时右列染 primary —— 折行文本要用户自己做减法。
class _StatsTable extends StatelessWidget {
  final AsyncValue<SyncStats> stats;

  const _StatsTable({required this.stats});

  @override
  Widget build(BuildContext context) {
    final value = switch (stats) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final error = switch (stats) {
      AsyncError(:final error) => '$error',
      _ => value?.remoteError,
    };

    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      children: [
        Padding(
          padding: const .fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              const Spacer(),
              _head(context, context.l10n.sync.columnLocal),
              _head(context, context.l10n.sync.columnRemote),
            ],
          ),
        ),
        _row(
          context,
          label: context.l10n.sync.rowDiary,
          local: value?.localDiaries,
          remote: value?.remoteDiaries,
        ),
        _row(
          context,
          label: context.l10n.sync.rowCategory,
          local: value?.localCategories,
          remote: value?.remoteCategories,
        ),
        _row(
          context,
          label: context.l10n.sync.rowMedia,
          local: value?.localMedia,
          remote: value?.remoteMedia,
        ),
        if (error != null)
          Padding(
            padding: const .fromLTRB(16, 8, 16, 0),
            child: Text(
              error,
              maxLines: 2,
              overflow: .ellipsis,
              style: context.theme.typography.bodySmall.error,
            ),
          ),
      ],
    );
  }

  Widget _head(BuildContext context, String label) => SizedBox(
    width: 56,
    child: Text(
      label,
      textAlign: .end,
      style: context.theme.typography.labelSmall.onSurfaceVariant,
    ),
  );

  Widget _row(
    BuildContext context, {
    required String label,
    required int? local,
    required int? remote,
  }) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final differs = local != null && remote != null && local != remote;
    Widget cell(int? n, {bool emphasize = false}) {
      final role = n == null
          ? typography.bodyMedium
          : typography.titleSmall.emphasized;
      final style = n == null
          ? role.onSurfaceVariant
          : emphasize
          ? role.primary
          : role.onSurface;
      return SizedBox(
        width: 56,
        child: Text(
          n?.toString() ?? '—',
          textAlign: .end,
          style: style.copyWith(fontFeatures: const [.tabularFigures()]),
        ),
      );
    }

    return Container(
      margin: const .only(bottom: 6),
      padding: const .symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppBorderRadius.mediumBorderRadius,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: typography.bodyMedium.onSurface)),
          cell(local),
          cell(remote, emphasize: differs),
        ],
      ),
    );
  }
}
