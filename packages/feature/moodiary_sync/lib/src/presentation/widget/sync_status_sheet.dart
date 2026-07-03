import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/application/sync_stats_controller.dart';
import 'package:moodiary_sync/src/application/user_key_controller.dart';
import 'package:moodiary_sync/src/application/sync_controller.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_logger.dart';
import 'package:moodiary_sync/src/presentation/widget/sync_key_guard.dart';
import 'package:moodiary_router/moodiary_router.dart';

/// 「同步状态」底部弹窗：配置标签 / 当前状态与进度 / 数据概览 / 立即同步
/// （同步中可停止）/ 查看日志入口。日志本身见 [SyncLogPage]。
Future<void> showSyncStatusSheet(BuildContext context) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
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
      case SyncEventKind.syncStart:
        _uploaded = 0;
        _downloaded = 0;
        _media = 0;
        _failed = 0;
      case SyncEventKind.diaryUpload || SyncEventKind.categoryUpload:
        _uploaded++;
      case SyncEventKind.diaryDownload || SyncEventKind.categoryDownload:
        _downloaded++;
      case SyncEventKind.mediaUpload || SyncEventKind.mediaDownload:
        _media++;
      case SyncEventKind.error:
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

    final scheme = context.colorScheme;
    final state = ref.watch(syncControllerProvider);
    final stats = ref.watch(syncStatsProvider);
    final backend = IRemoteSyncBackend.get();
    final encryption = ref
        .watch(userKeyControllerProvider)
        .maybeWhen(
          data: (key) => key != null && key.isNotEmpty,
          orElse: () => false,
        );
    final running = state is SyncRunning;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Tag(
                        icon: backend.type == SyncProviderType.webdav
                            ? Icons.cloud_outlined
                            : Icons.storage_rounded,
                        label: backend.type.label,
                      ),
                      _Tag(
                        icon: encryption ? Icons.lock_outline : Icons.lock_open,
                        label: encryption ? '已加密' : '未加密',
                      ),
                      if (!backend.isReady)
                        const _Tag(
                          icon: Icons.error_outline,
                          label: '未配置',
                          emphasis: true,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '刷新数据概览',
                  icon: const Icon(Icons.refresh_rounded),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  color: scheme.onSurfaceVariant,
                  onPressed: () => ref.invalidate(syncStatsProvider),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _StateSection(
                state: state,
                uploaded: _uploaded,
                downloaded: _downloaded,
                media: _media,
                failed: _failed,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _MetricsLine(stats: stats),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('查看日志'),
                  onPressed: () =>
                      Navigator.of(context).pop(_SyncStatusSheet.resultViewLog),
                ),
                const Spacer(),
                if (!running)
                  FilledButton.icon(
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('立即同步'),
                    onPressed: backend.isReady
                        ? () async {
                            if (!await ensureSyncKeyReady(
                              context: context,
                              ref: ref,
                              backend: backend,
                            )) {
                              return;
                            }
                            await ref
                                .read(syncControllerProvider.notifier)
                                .sync(IRemoteSyncBackend.get());
                          }
                        : null,
                  )
                else
                  ValueListenableBuilder(
                    valueListenable: SyncCancellation.instance.listenable,
                    builder: (context, stopping, _) {
                      return FilledButton.tonalIcon(
                        icon: const Icon(Icons.stop_rounded, size: 18),
                        label: Text(stopping ? '正在停止…' : '停止同步'),
                        onPressed: stopping
                            ? null
                            : () => ref
                                  .read(syncControllerProvider.notifier)
                                  .stop(),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;

  /// true → 警示配色（errorContainer），用于「未配置」。
  final bool emphasis;

  const _Tag({required this.icon, required this.label, this.emphasis = false});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final bg = emphasis ? scheme.errorContainer : scheme.secondaryContainer;
    final fg = emphasis ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(label, style: context.textTheme.labelSmall?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

class _StateSection extends StatelessWidget {
  final SyncState state;
  final int uploaded;
  final int downloaded;
  final int media;
  final int failed;

  const _StateSection({
    required this.state,
    required this.uploaded,
    required this.downloaded,
    required this.media,
    required this.failed,
  });

  Widget _line(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String text,
    Color? textColor,
  }) {
    final scheme = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: context.textTheme.bodySmall?.copyWith(
              color: textColor ?? scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return switch (state) {
      SyncRunning(:final label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // year2023: false → 2024 版 M3 进度条；该参数为迁移期 deprecated 标记，未来默认即 false。
          // ignore: deprecated_member_use
          const LinearProgressIndicator(year2023: false),
          const SizedBox(height: 10),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '上传 $uploaded · 下载 $downloaded · 媒体 $media'),
                if (failed > 0)
                  TextSpan(
                    text: ' · 失败 $failed',
                    style: TextStyle(color: scheme.error),
                  ),
              ],
            ),
            style: context.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      SyncSuccess(:final message) => _line(
        context,
        icon: Icons.check_circle_rounded,
        iconColor: scheme.primary,
        text: message,
        textColor: scheme.onSurface,
      ),
      SyncError(:final message) => _line(
        context,
        icon: Icons.error_rounded,
        iconColor: scheme.error,
        text: message,
        textColor: scheme.error,
      ),
      SyncIdle() => ValueListenableBuilder(
        valueListenable: MoodiaryKVs.lastSyncTime.getNotifier(),
        builder: (context, millis, _) => _line(
          context,
          icon: Icons.schedule_rounded,
          iconColor: scheme.onSurfaceVariant,
          text: millis > 0
              ? '上次同步：${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(millis))}'
              : '尚未同步',
        ),
      ),
    };
  }
}

class _MetricsLine extends StatelessWidget {
  final AsyncValue<SyncStats> stats;
  const _MetricsLine({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final style = context.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return switch (stats) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 2,
            children: [
              Text(
                '本地：日记 ${value.localDiaries} · 分类 ${value.localCategories}',
                style: style,
              ),
              Text(
                value.remoteDiaries != null
                    ? '远端：日记 ${value.remoteDiaries} · 分类 ${value.remoteCategories} · 媒体 ${value.remoteMedia}'
                    : '远端：—',
                style: style,
              ),
            ],
          ),
          if (value.remoteError != null) ...[
            const SizedBox(height: 4),
            Text(
              value.remoteError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
      AsyncError(:final error) => Text(
        '数据概览加载失败：$error',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodySmall?.copyWith(color: scheme.error),
      ),
      _ => Text(
        '正在获取数据概览…',
        style: context.textTheme.bodySmall?.copyWith(color: scheme.outline),
      ),
    };
  }
}
