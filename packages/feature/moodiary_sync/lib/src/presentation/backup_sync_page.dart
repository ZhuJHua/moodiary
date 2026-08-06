import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_sync/src/application/sync_controller.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_registry.dart';
import 'package:moodiary_sync/src/presentation/widget/s3_form_sheet.dart';
import 'package:moodiary_sync/src/presentation/widget/sync_key_guard.dart';
import 'package:moodiary_sync/src/presentation/widget/user_key_tile.dart';
import 'package:moodiary_sync/src/presentation/widget/webdav_form_sheet.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class BackupSyncPage extends ConsumerWidget {
  const BackupSyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<SyncState>(syncControllerProvider, (prev, next) {
      switch (next) {
        case SyncSuccess(:final message):
          toast.success(message: '完成：$message');
          ref.read(syncControllerProvider.notifier).reset();
        case SyncError(:final message):
          toast.error(message: '失败：$message');
          ref.read(syncControllerProvider.notifier).reset();
        default:
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('备份与同步')),
      body: ListView(
        padding: const .symmetric(horizontal: 8, vertical: 8),
        children: const [
          _RemoteSection(),
          SizedBox(height: 4),
          _LanSection(),
          SizedBox(height: 4),
          _EncryptionSection(),
          SizedBox(height: 4),
          _AutoSyncSection(),
          SizedBox(height: 4),
          _NetworkSection(),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RemoteSection extends ConsumerStatefulWidget {
  const _RemoteSection();

  @override
  ConsumerState<_RemoteSection> createState() => _RemoteSectionState();
}

class _RemoteSectionState extends ConsumerState<_RemoteSection> {
  Future<void> _switchProvider(SyncProviderType type) async {
    await SyncProviderType.setCurrent(type);
    await registerRemoteSync();
    if (mounted) setState(() {});
  }

  Future<void> _testConnection() async {
    final backend = IRemoteSyncBackend.get();
    if (!backend.isReady) {
      toast.info(message: '请先完成配置');
      return;
    }
    toast.loading(message: '正在测试连接...');
    final err = await backend.testConnection();
    await toast.dismiss();
    if (err == null) {
      toast.success(message: '连接成功');
    } else {
      toast.error(message: '连接失败：$err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final current = SyncProviderType.current();
    final backend = IRemoteSyncBackend.get();
    final configured = backend.isReady;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const SettingTitleTile(title: '云端同步'),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SettingListTile(
                isFirst: true,
                title: '同步方式',
                leading: const Icon(LucideIcons.arrowRightLeft),
                trailing: Text(
                  current.label,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                onTap: () => _pickProvider(context, current),
              ),
              SettingListTile(
                title: '${current.label} 配置',
                leading: Icon(
                  current == .webdav ? LucideIcons.cloud : LucideIcons.database,
                ),
                subtitle: configured ? '已配置' : '未配置（点击设置）',
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () async {
                  final ok = current == .webdav
                      ? await WebDavFormSheet.show(context)
                      : await S3FormSheet.show(context);
                  if (ok != true || !mounted) return;
                  setState(() {});
                  if (!context.mounted) return;
                  // 新设备接入：远端若已加密而本地无密钥，保存配置后立即引导配置。
                  await ensureSyncKeyReady(
                    context: context,
                    ref: ref,
                    backend: .get(),
                  );
                },
              ),
              SettingListTile(
                title: '测试连接',
                leading: const Icon(LucideIcons.plugZap),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: configured ? _testConnection : null,
              ),
              ValueListenableBuilder(
                valueListenable: MoodiaryKVs.lastSyncTime.getNotifier(),
                builder: (context, millis, _) {
                  final syncState = ref.watch(syncControllerProvider);
                  final running = syncState is SyncRunning;
                  if (running) {
                    return ValueListenableBuilder(
                      valueListenable: SyncCancellation.instance.listenable,
                      builder: (context, stopping, _) {
                        return SettingListTile(
                          title: stopping ? '正在停止…' : '停止同步',
                          subtitle: stopping ? '等待当前条目完成后收尾' : '正在后台同步，点击停止',
                          leading: const Icon(LucideIcons.circleStop),
                          trailing: const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          onTap: stopping
                              ? null
                              : () {
                                  ref
                                      .read(syncControllerProvider.notifier)
                                      .stop();
                                  toast.info(message: '将在当前条目完成后停止');
                                },
                        );
                      },
                    );
                  }
                  return SettingListTile(
                    title: '立即同步',
                    subtitle: millis > 0
                        ? '上次同步：${TimeFormat.listDateTime(.fromMillisecondsSinceEpoch(millis))}'
                        : '尚未同步',
                    leading: const Icon(LucideIcons.refreshCw),
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: configured
                        ? () async {
                            final backend = IRemoteSyncBackend.get();
                            if (!await ensureSyncKeyReady(
                              context: context,
                              ref: ref,
                              backend: backend,
                            )) {
                              return;
                            }
                            await ref
                                .read(syncControllerProvider.notifier)
                                .sync(backend);
                          }
                        : null,
                  );
                },
              ),
              SettingListTile(
                isLast: true,
                title: '同步日志',
                subtitle: '按日期查看同步事件',
                leading: const Icon(LucideIcons.history),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => const SyncLogRoute().push(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickProvider(
    BuildContext context,
    SyncProviderType current,
  ) async {
    final picked = await showMoodiaryPickerSheet<SyncProviderType>(
      context,
      title: '同步方式',
      icon: LucideIcons.arrowRightLeft,
      selected: current,
      options: [
        for (final t in SyncProviderType.values)
          MoodiarySheetOption(value: t, label: t.label),
      ],
    );
    if (picked == null || picked == current) return;
    await _switchProvider(picked);
  }
}

class _LanSection extends StatelessWidget {
  const _LanSection();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const SettingTitleTile(title: '局域网同步'),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              SettingListTile(
                isFirst: true,
                title: '发送',
                subtitle: '发送日记到同一 Wi-Fi 下的设备',
                leading: const Icon(LucideIcons.radioTower),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => const LanSendRoute().push(context),
              ),
              SettingListTile(
                isLast: true,
                title: '接收',
                subtitle: '等待其它设备发送到本机',
                leading: const Icon(LucideIcons.wifi),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => const LanReceiveRoute().push(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EncryptionSection extends StatelessWidget {
  const _EncryptionSection();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const SettingTitleTile(title: '加密'),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          // 无独立加密开关：配置用户密钥即开启 AES-256 加密，清空即回到明文。
          child: const Column(
            children: [UserKeyTile(isFirst: true, isLast: true)],
          ),
        ),
      ],
    );
  }
}

class _AutoSyncSection extends StatelessWidget {
  const _AutoSyncSection();

  static const List<int> _pollPresets = [10, 15, 30, 60, 120, 300, 600];

  static const int _frequentThreshold = 30;

  static String _fmtInterval(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '$m 分钟' : '$m 分 $s 秒';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const SettingTitleTile(title: '自动同步'),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: ValueListenableBuilder(
            valueListenable: MoodiaryKVs.autoSync.getNotifier(),
            builder: (context, enabled, _) {
              return Column(
                children: [
                  SettingSwitchListTile(
                    isFirst: true,
                    title: '自动同步',
                    subtitle: '日记变更后自动推送，并定时拉取其它设备的变更',
                    secondary: const Icon(LucideIcons.refreshCw),
                    value: enabled,
                    onChanged: (v) => MoodiaryKVs.autoSync.set(v),
                  ),
                  ValueListenableBuilder(
                    valueListenable: MoodiaryKVs.syncPollInterval.getNotifier(),
                    builder: (context, seconds, _) {
                      return SettingListTile(
                        isLast: true,
                        title: '轮询间隔',
                        subtitle: '每隔此时间在后台拉取其它设备的变更',
                        leading: const Icon(LucideIcons.timer),
                        trailing: Text(
                          _fmtInterval(seconds),
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: enabled
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: enabled
                            ? () => _editPollInterval(context, seconds)
                            : null,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _editPollInterval(BuildContext context, int current) async {
    // 取不大于当前值的最大预设作为初始游标。
    int index = 0;
    for (var i = 0; i < _pollPresets.length; i++) {
      if (_pollPresets[i] <= current) index = i;
    }
    // 只在按下「确定」时落盘，「取消」就是真的取消。
    final picked = await showMoodiarySheet<int>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final seconds = _pollPresets[index];
          final tooFrequent = seconds < _frequentThreshold;
          return MoodiarySheetScaffold<int>(
            title: '轮询间隔',
            subtitle: _fmtInterval(seconds),
            icon: LucideIcons.timer,
            actions: [
              MoodiaryAction(label: ctx.l10n.cancel),
              MoodiaryAction(
                label: ctx.l10n.ok,
                value: _pollPresets[index],
                isPrimary: true,
              ),
            ],
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Text(
                  '每隔此时间在后台跑一次双向同步。间隔越短，与其它设备的变更同步越及时；'
                  '但每次轮询都会抢占远端锁、读取清单并发起网络请求 —— 间隔过短会显著'
                  '增加流量与耗电，还可能触发 WebDAV / S3 服务端限流甚至临时封禁。'
                  '建议不低于 30 秒。',
                  style: ctx.textTheme.bodySmall?.copyWith(
                    color: tooFrequent
                        ? ctx.colorScheme.error
                        : ctx.colorScheme.onSurfaceVariant,
                  ),
                ),
                Slider(
                  value: index.toDouble(),
                  min: 0,
                  max: (_pollPresets.length - 1).toDouble(),
                  divisions: _pollPresets.length - 1,
                  label: _fmtInterval(seconds),
                  onChanged: (v) => setSheetState(() => index = v.round()),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (picked != null) await MoodiaryKVs.syncPollInterval.set(picked);
  }
}

class _NetworkSection extends StatelessWidget {
  const _NetworkSection();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const SettingTitleTile(title: '网络'),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: ValueListenableBuilder(
            valueListenable: MoodiaryKVs.syncConcurrency.getNotifier(),
            builder: (context, value, _) {
              return SettingListTile(
                isFirst: true,
                isLast: true,
                title: '并发请求数',
                subtitle: '同步时同时进行的网络请求上限，弱网或服务端限流时调小',
                leading: const Icon(LucideIcons.server),
                trailing: Text(
                  '$value',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                onTap: () => _editConcurrency(context, value),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _editConcurrency(BuildContext context, int current) async {
    double value = current.clamp(1, 16).toDouble();
    final picked = await showMoodiarySheet<int>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return MoodiarySheetScaffold<int>(
            title: '并发请求数',
            subtitle: '${value.round()}',
            icon: LucideIcons.server,
            actions: [
              MoodiaryAction(label: ctx.l10n.cancel),
              MoodiaryAction(
                label: ctx.l10n.ok,
                value: value.round(),
                isPrimary: true,
              ),
            ],
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Text(
                  '默认 8。值越大同步越快，但可能触发 WebDAV / S3 服务端限流或连接拒绝。',
                  style: ctx.textTheme.bodySmall?.copyWith(
                    color: ctx.colorScheme.onSurfaceVariant,
                  ),
                ),
                Slider(
                  value: value,
                  min: 1,
                  max: 16,
                  divisions: 15,
                  label: '${value.round()}',
                  onChanged: (v) => setSheetState(() => value = v),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (picked != null) await MoodiaryKVs.syncConcurrency.set(picked);
  }
}
