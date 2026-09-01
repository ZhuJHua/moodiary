import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/application/sync_controller.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/data/sync_registry.dart';
import 'package:moodiary_sync/src/presentation/widget/s3_form_sheet.dart';
import 'package:moodiary_sync/src/presentation/widget/sync_key_guard.dart';
import 'package:moodiary_sync/src/presentation/widget/user_key_tile.dart';
import 'package:moodiary_sync/src/presentation/widget/webdav_form_sheet.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

class BackupSyncPage extends ConsumerWidget {
  const BackupSyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<SyncState>(syncControllerProvider, (prev, next) {
      switch (next) {
        case SyncSuccess(:final message):
          toast.success(message: l10n.sync.doneToast(message: message));
          ref.read(syncControllerProvider.notifier).reset();
        case SyncError(:final message):
          toast.error(message: l10n.sync.failedToast(message: message));
          ref.read(syncControllerProvider.notifier).reset();
        default:
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sync.pageTitle)),
      body: Padding(
        padding: const .symmetric(horizontal: 8.0),
        child: CustomScrollView(
          slivers: [
            const _RemoteSection(),
            const _LanSection(),
            const _EncryptionSection(),
            const _AutoSyncSection(),
            const _NetworkSection(),
            SliverGap(context.safeBottom),
          ],
        ),
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
  /// 密钥冲突标记由引擎在同步途中写入（无 UI），页面得自己听着才会亮出入口。
  late final KVNotifier<List<String>> _keyConflicts = MoodiaryKVs
      .syncKeyConflictBackends
      .getNotifierOr(const <String>[]);

  @override
  void initState() {
    super.initState();
    _keyConflicts.addListener(_onKeyConflictChanged);
  }

  @override
  void dispose() {
    _keyConflicts.removeListener(_onKeyConflictChanged);
    super.dispose();
  }

  void _onKeyConflictChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _unlockRemoteKey() async {
    await ensureSyncKeyReady(context: context, ref: ref, backend: .get());
    if (mounted) setState(() {});
  }

  Future<void> _switchProvider(SyncProviderType type) async {
    SyncProviderType.setCurrent(type);
    await RemoteSyncRegistry.get().reload();
    if (mounted) setState(() {});
  }

  Future<void> _testConnection() async {
    final backend = IRemoteSyncBackend.get();
    if (!backend.isReady) {
      toast.info(message: l10n.sync.configureFirst);
      return;
    }
    toast.loading(message: l10n.sync.testing);
    final err = await backend.testConnection();
    await toast.dismiss();
    if (err == null) {
      toast.success(message: l10n.sync.connectOk);
    } else {
      toast.error(message: l10n.sync.connectFailed(error: err));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = SyncProviderType.current();
    final backend = IRemoteSyncBackend.get();
    final configured = backend.isReady;
    return MSliverSettingGroup(
      title: context.l10n.sync.cloudSection,
      children: [
        SettingListTile(
          title: context.l10n.sync.method,
          leading: const Icon(LucideIcons.arrowRightLeft),
          trailing: Text(
            current.label,
            style: context.theme.typography.bodySmall.primary,
          ),
          onTap: () => _pickProvider(context, current),
        ),
        SettingListTile(
          title: context.l10n.sync.methodConfig(name: current.label),
          leading: Icon(
            current == .webdav ? LucideIcons.cloud : LucideIcons.database,
          ),
          subtitle: configured
              ? context.l10n.common.configured
              : context.l10n.sync.notConfiguredTap,
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
        if (SyncKeyManager.hasKeyConflict(backend.persistentBackendId))
          SettingListTile(
            title: context.l10n.sync.keyConflictTitle,
            subtitle: context.l10n.sync.keyConflictSubtitle,
            leading: Icon(
              LucideIcons.lockKeyhole,
              color: context.theme.colors.error,
            ),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: _unlockRemoteKey,
          ),
        SettingListTile(
          title: context.l10n.sync.testConnection,
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
                    title: stopping
                        ? context.l10n.sync.stopping
                        : context.l10n.sync.stop,
                    subtitle: stopping
                        ? context.l10n.sync.stoppingSubtitle
                        : context.l10n.sync.stopSubtitle,
                    leading: const Icon(LucideIcons.circleStop),
                    trailing: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    onTap: stopping
                        ? null
                        : () {
                            ref.read(syncControllerProvider.notifier).stop();
                            toast.info(message: l10n.sync.willStop);
                          },
                  );
                },
              );
            }
            return SettingListTile(
              title: context.l10n.sync.syncNow,
              subtitle: millis > 0
                  ? context.l10n.sync.lastSync(
                      time: TimeFormat.listDateTime(
                        .fromMillisecondsSinceEpoch(millis),
                      ),
                    )
                  : context.l10n.sync.neverSynced,
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
          title: context.l10n.sync.logEntry,
          subtitle: context.l10n.sync.logEntrySubtitle,
          leading: const Icon(LucideIcons.history),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => const SyncLogRoute().push(context),
        ),
      ],
    );
  }

  Future<void> _pickProvider(
    BuildContext context,
    SyncProviderType current,
  ) async {
    final picked = await MSheet.picker<SyncProviderType>(
      context,
      title: l10n.sync.method,
      icon: LucideIcons.arrowRightLeft,
      selected: current,
      options: [
        for (final t in SyncProviderType.values)
          MSheetOption(value: t, label: t.label),
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
    return MSliverSettingGroup(
      title: context.l10n.sync.lanSection,
      children: [
        SettingListTile(
          title: context.l10n.sync.lanSend,
          subtitle: context.l10n.sync.lanSendSubtitle,
          leading: const Icon(LucideIcons.radioTower),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => const LanSendRoute().push(context),
        ),
        SettingListTile(
          title: context.l10n.sync.lanReceive,
          subtitle: context.l10n.sync.lanReceiveSubtitle,
          leading: const Icon(LucideIcons.wifi),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => const LanReceiveRoute().push(context),
        ),
      ],
    );
  }
}

class _EncryptionSection extends StatelessWidget {
  const _EncryptionSection();

  @override
  Widget build(BuildContext context) {
    // 无独立加密开关：配置用户密钥即开启 AES-256 加密，清空即回到明文。
    return MSliverSettingGroup(
      title: context.l10n.sync.encryptionSection,
      children: const [UserKeyTile()],
    );
  }
}

class _AutoSyncSection extends StatelessWidget {
  const _AutoSyncSection();

  static const List<int> _pollPresets = [10, 15, 30, 60, 120, 300, 600];

  static const int _frequentThreshold = 30;

  static String _fmtInterval(int seconds) {
    if (seconds < 60) return l10n.sync.seconds(count: seconds);
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0
        ? l10n.sync.minutes(count: m)
        : l10n.sync.minutesSeconds(minutes: m, seconds: s);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: MoodiaryKVs.autoSync.getNotifier(),
      builder: (context, enabled, _) {
        return MSliverSettingGroup(
          title: context.l10n.sync.autoSection,
          children: [
            SettingSwitchListTile(
              title: context.l10n.sync.autoSync,
              subtitle: context.l10n.sync.autoSyncSubtitle,
              secondary: const Icon(LucideIcons.refreshCw),
              value: enabled,
              onChanged: (v) => MoodiaryKVs.autoSync.set(v),
            ),
            ValueListenableBuilder(
              valueListenable: MoodiaryKVs.syncPollInterval.getNotifier(),
              builder: (context, seconds, _) {
                return SettingListTile(
                  title: context.l10n.sync.pollInterval,
                  subtitle: context.l10n.sync.pollIntervalSubtitle,
                  leading: const Icon(LucideIcons.timer),
                  trailing: Text(
                    _fmtInterval(seconds),
                    style: enabled
                        ? context.theme.typography.bodyMedium.primary
                        : context.theme.typography.bodyMedium.onSurfaceVariant,
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
    );
  }

  Future<void> _editPollInterval(BuildContext context, int current) async {
    // 取不大于当前值的最大预设作为初始游标。
    int index = 0;
    for (var i = 0; i < _pollPresets.length; i++) {
      if (_pollPresets[i] <= current) index = i;
    }
    // 只在按下「确定」时落盘，「取消」就是真的取消。
    final picked = await MSheet.show<int>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final seconds = _pollPresets[index];
          final tooFrequent = seconds < _frequentThreshold;
          return MSheetScaffold<int>(
            title: l10n.sync.pollInterval,
            subtitle: _fmtInterval(seconds),
            icon: LucideIcons.timer,
            actions: [
              MAction(label: ctx.l10n.common.cancel),
              MAction(
                label: ctx.l10n.common.ok,
                value: _pollPresets[index],
                isPrimary: true,
              ),
            ],
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Text(
                  l10n.sync.pollIntervalNote,
                  style: tooFrequent
                      ? ctx.theme.typography.bodySmall.error
                      : ctx.theme.typography.bodySmall.onSurfaceVariant,
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
    if (picked != null) MoodiaryKVs.syncPollInterval.set(picked);
  }
}

class _NetworkSection extends StatelessWidget {
  const _NetworkSection();

  @override
  Widget build(BuildContext context) {
    return MSliverSettingGroup(
      title: context.l10n.sync.networkSection,
      children: [
        ValueListenableBuilder(
          valueListenable: MoodiaryKVs.syncConcurrency.getNotifier(),
          builder: (context, value, _) {
            return SettingListTile(
              title: context.l10n.sync.concurrency,
              subtitle: context.l10n.sync.concurrencySubtitle,
              leading: const Icon(LucideIcons.server),
              trailing: Text(
                '$value',
                style: context.theme.typography.bodyMedium.primary,
              ),
              onTap: () => _editConcurrency(context, value),
            );
          },
        ),
      ],
    );
  }

  Future<void> _editConcurrency(BuildContext context, int current) async {
    double value = current.clamp(1, 16).toDouble();
    final picked = await MSheet.show<int>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return MSheetScaffold<int>(
            title: l10n.sync.concurrency,
            subtitle: '${value.round()}',
            icon: LucideIcons.server,
            actions: [
              MAction(label: ctx.l10n.common.cancel),
              MAction(
                label: ctx.l10n.common.ok,
                value: value.round(),
                isPrimary: true,
              ),
            ],
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Text(
                  l10n.sync.concurrencyNote,
                  style: ctx.theme.typography.bodySmall.onSurfaceVariant,
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
    if (picked != null) MoodiaryKVs.syncConcurrency.set(picked);
  }
}
