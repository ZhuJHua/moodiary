import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/application/sync_stats_controller.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/application/sync_controller.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/presentation/widget/sync_key_guard.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// 「同步状态」底部弹窗：配置标签 / 当前状态与进度 / 数据概览 / 立即同步
/// （同步中可停止）/ 查看日志入口。日志本身见 [SyncLogPage]。
Future<void> showSyncStatusSheet(BuildContext context) async {
  final result = await showMoodiarySheet<String>(
    context,
    builder: (_) => const _SyncStatusSheet(),
  );
  // 等弹窗收起后再用外层 context 导航：弹窗自己的 context pop 后已卸载。
  if (result == _SyncStatusSheet.resultViewLog && context.mounted) {
    const SyncLogRoute().push(context);
  }
}

class _SyncStatusSheet extends ConsumerStatefulWidget {
  static const String resultViewLog = 'viewLog';

  const _SyncStatusSheet();

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
    for (final event in SyncLogger.get().recent) {
      _applyCounter(event);
    }
    _sub = SyncLogger.get().events.listen((event) {
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
        _uploaded++;
      case .diaryDownload || .categoryDownload:
        _downloaded++;
      case .mediaUpload || .mediaDownload:
        _media++;
      case .error:
        _failed++;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SyncState>(syncControllerProvider, (prev, next) {
      if (next is SyncSuccess || next is SyncError) {
        ref.invalidate(syncStatsProvider);
      }
    });

    final state = ref.watch(syncControllerProvider);
    final stats = ref.watch(syncStatsProvider);
    final backend = IRemoteSyncBackend.get();
    final encryption = ref
        .watch(syncDekControllerProvider)
        .maybeWhen(
          data: (key) => key != null && key.isNotEmpty,
          orElse: () => false,
        );
    final running = state is SyncRunning;

    // 「立即同步 / 停止同步」自行接管点击：同步跑起来后弹窗要留着看进度，不能关。
    MoodiarySheetScaffold<String> buildSheet(bool stopping) {
      return MoodiarySheetScaffold<String>(
        title: '同步状态',
        // 后端与加密是背景事实不是状态，降到副标题，别跟「同步失败」抢同一级视觉。
        subtitle: '${backend.type.label} · ${encryption ? '已加密' : '未加密'}',
        icon: backend.type == .webdav
            ? LucideIcons.cloud
            : LucideIcons.database,
        actions: [
          const MoodiaryAction(
            label: '查看日志',
            value: _SyncStatusSheet.resultViewLog,
          ),
          if (!running)
            MoodiaryAction(
              label: '立即同步',
              isPrimary: true,
              enabled: backend.isReady,
              onPressed: () async {
                if (!await ensureSyncKeyReady(
                  context: context,
                  ref: ref,
                  backend: backend,
                )) {
                  return;
                }
                await ref.read(syncControllerProvider.notifier).sync(.get());
              },
            )
          else
            MoodiaryAction(
              label: stopping ? '正在停止…' : '停止同步',
              isPrimary: true,
              enabled: !stopping,
              onPressed: () => ref.read(syncControllerProvider.notifier).stop(),
            ),
        ],
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            _StateCard(
              state: state,
              configured: backend.isReady,
              stats: stats,
              uploaded: _uploaded,
              downloaded: _downloaded,
              media: _media,
              failed: _failed,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: MoodiaryFormSection('数据概览')),
                IconButton(
                  tooltip: '刷新数据概览',
                  icon: const Icon(LucideIcons.rotateCw),
                  iconSize: 16,
                  visualDensity: .compact,
                  color: context.colorScheme.onSurfaceVariant,
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

    if (!running) return buildSheet(false);
    return ValueListenableBuilder(
      valueListenable: SyncCancellation.instance.listenable,
      builder: (context, stopping, _) => buildSheet(stopping),
    );
  }
}

/// 状态卡：一行结论 + 一行佐证，是这张弹窗唯一的主视觉。四态各有自己的图标与配色，
/// 失败与未配置走 error 底纹 —— 「未配置」是唯一需要用户离开去做点什么的状态，
/// 藏在一堆胶囊标签里等于没说。
class _StateCard extends StatelessWidget {
  final SyncState state;
  final bool configured;
  final AsyncValue<SyncStats> stats;
  final int uploaded;
  final int downloaded;
  final int media;
  final int failed;

  const _StateCard({
    required this.state,
    required this.configured,
    required this.stats,
    required this.uploaded,
    required this.downloaded,
    required this.media,
    required this.failed,
  });

  /// 从未同步过时，若远端已有内容就把「有多少可拉」说出来。
  String? _pendingHint() {
    final remote = switch (stats) {
      AsyncData(:final value) => value.remoteDiaries,
      _ => null,
    };
    if (remote == null || remote == 0) return null;
    return '远端有 $remote 篇日记待拉取';
  }

  @override
  Widget build(BuildContext context) {
    if (state case SyncRunning(:final label)) {
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
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: .w600,
                color: context.colorScheme.onSurface,
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

    return switch (state) {
      SyncSuccess(:final message) => _Line(
        icon: LucideIcons.circleCheck,
        title: '同步完成',
        detail: message,
      ),
      SyncError(:final message) => _Line(
        icon: LucideIcons.triangleAlert,
        title: '同步失败',
        detail: message,
        warn: true,
      ),
      _ when !configured => const _Line(
        icon: LucideIcons.unplug,
        title: '未配置同步后端',
        detail: '去「备份与同步」填一个',
        warn: true,
      ),
      _ => ValueListenableBuilder(
        valueListenable: MoodiaryKVs.lastSyncTime.getNotifier(),
        builder: (context, millis, _) => millis > 0
            ? _Line(
                icon: LucideIcons.circleCheck,
                // 只说「同步过」这个事实：两侧条目数相等也不代表内容一致，
                // 差异由下面的对照表用颜色说。
                title: '已同步',
                detail:
                    '上次同步 '
                    '${TimeFormat.listDateTime(.fromMillisecondsSinceEpoch(millis))}',
              )
            : _Line(
                icon: LucideIcons.clock,
                title: '尚未同步',
                detail: _pendingHint(),
              ),
      ),
    };
  }
}

class _Shell extends StatelessWidget {
  final bool warn;
  final Widget child;

  const _Shell({required this.warn, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
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
    final scheme = context.colorScheme;
    final accent = warn ? scheme.error : scheme.primary;
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
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: .w600,
                    color: warn ? scheme.error : scheme.onSurface,
                  ),
                ),
                if (detail != null)
                  Padding(
                    padding: const .only(top: 2),
                    child: Text(
                      detail!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
    final scheme = context.colorScheme;
    final color = bad ? scheme.error : scheme.onSurfaceVariant;
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
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            '$value',
            style: context.textTheme.labelMedium?.copyWith(
              color: color,
              fontFeatures: const [.tabularFigures()],
            ),
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
    final scheme = context.colorScheme;
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
              _head(context, '本地'),
              _head(context, '远端'),
            ],
          ),
        ),
        _row(
          context,
          label: '日记',
          local: value?.localDiaries,
          remote: value?.remoteDiaries,
        ),
        _row(
          context,
          label: '分类',
          local: value?.localCategories,
          remote: value?.remoteCategories,
        ),
        // 本地媒体没有统计口径（SyncStats 只数日记与分类），宁可留空也不编。
        _row(context, label: '媒体', local: null, remote: value?.remoteMedia),
        if (error != null)
          Padding(
            padding: const .fromLTRB(16, 8, 16, 0),
            child: Text(
              error,
              maxLines: 2,
              overflow: .ellipsis,
              style: context.textTheme.bodySmall?.copyWith(color: scheme.error),
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
      style: context.textTheme.labelSmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _row(
    BuildContext context, {
    required String label,
    required int? local,
    required int? remote,
  }) {
    final scheme = context.colorScheme;
    final differs = local != null && remote != null && local != remote;
    Widget cell(int? n, {bool emphasize = false}) => SizedBox(
      width: 56,
      child: Text(
        n?.toString() ?? '—',
        textAlign: .end,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: n == null ? .w400 : .w600,
          color: n == null
              ? scheme.onSurfaceVariant
              : emphasize
              ? scheme.primary
              : scheme.onSurface,
          fontFeatures: const [.tabularFigures()],
        ),
      ),
    );

    return Container(
      margin: const .only(bottom: 6),
      padding: const .symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppBorderRadius.mediumBorderRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
          cell(local),
          cell(remote, emphasize: differs),
        ],
      ),
    );
  }
}
