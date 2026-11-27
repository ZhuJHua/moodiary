import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/src/application/sync_controller.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:moodiary_sync/src/data/sync_data_providers.dart';
import 'package:moodiary_sync/src/presentation/manual_sync.dart';
import 'package:moodiary_sync/src/presentation/widget/s3_form_sheet.dart';
import 'package:moodiary_sync/src/presentation/widget/sync_key_guard.dart';
import 'package:moodiary_sync/src/presentation/widget/sync_labels.dart';
import 'package:moodiary_sync/src/presentation/widget/user_key_tile.dart';
import 'package:moodiary_sync/src/presentation/widget/webdav_form_sheet.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class BackupSyncPage extends ConsumerWidget {
  const BackupSyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(syncControllerProvider, (prev, next) {
      final outcome = next.last?.outcome;
      if (outcome == null ||
          outcome.trigger != SyncTrigger.manual ||
          next.last!.bannerDismissed ||
          prev?.last?.outcome == outcome) {
        return;
      }
      switch (outcome.kind) {
        case .failed:
          toast.error(message: l10n.sync.failedToast(message: outcome.message));
        case .partial || .stopped:
          toast.error(message: outcome.message);
        case .changed || .upToDate:
          toast.success(message: l10n.sync.doneToast(message: outcome.message));
      }
      ref.read(syncControllerProvider.notifier).dismissBanner();
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
  Future<void> _unlockRemoteKey() async {
    try {
      await ref
          .read(syncOperationGuardProvider)
          .tryWithOperation(
            (operation) => ensureSyncKeyReady(
              operation: operation,
              context: context,
              ref: ref,
              backend: ref.read(activeSyncBackendProvider),
            ),
          );
    } on SyncException catch (error) {
      if (mounted) toast.error(message: error.message);
    }
  }

  Future<void> _syncNow() async {
    final result = await triggerManualSync(
      context: context,
      ref: ref,
      canPrompt: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false),
    );
    if (!mounted) return;
    switch (result) {
      case ManualSyncUnreachable():
        toast.error(message: context.l10n.sync.pullUnreachable);
      case ManualSyncFailed():
        toast.error(message: context.l10n.sync.pullFailed);
      default:
        break;
    }
  }

  Future<void> _testConnection() async {
    toast.loading(message: l10n.sync.testing);
    try {
      final tested = await ref
          .read(syncControllerProvider.notifier)
          .testConnection();
      await toast.dismiss();
      if (tested) toast.success(message: l10n.sync.connectOk);
    } on SyncException catch (e) {
      await toast.dismiss();
      toast.error(message: e.message);
    }
  }

  Widget _backendSubtitle(BuildContext context, bool configured) {
    if (!configured) return Text(context.l10n.sync.notConfiguredTap);
    final status = ref.watch(syncControllerProvider);
    final scheme = context.theme.colors;
    final short = syncHealthShort(context.l10n, status.health);
    final since = status.healthSince;
    final text = [
      context.l10n.common.configured,
      if (short != null)
        status.health.isBad && since != null
            ? '$short（${TimeFormat.clock(since)}）'
            : short,
    ].join(' · ');
    return Row(
      mainAxisSize: .min,
      children: [
        if (short != null) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: .circle,
              color: status.health.isBad ? scheme.error : scheme.primary,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(child: Text(text, overflow: .ellipsis)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(activeSyncProviderTypeProvider);
    final configured = ref.watch(syncBackendReadyProvider).value ?? false;
    final busy = ref.watch(syncOperationBusyProvider);
    final conflicts = ref.watch(
      kvValueOrProvider(MoodiaryKVs.syncKeyConflictBackends, const <String>[]),
    );
    final millis = ref.watch(kvValueProvider(MoodiaryKVs.lastSyncTime));
    final status = ref.watch(syncControllerProvider);
    final stopping = status.stopping;
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
          onTap: busy ? null : () => _pickProvider(context, current),
        ),
        SettingListTile(
          title: context.l10n.sync.methodConfig(name: current.label),
          leading: Icon(
            current == .webdav ? LucideIcons.cloud : LucideIcons.database,
          ),
          subtitle: _backendSubtitle(context, configured),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: busy
              ? null
              : () async {
                  if (!await AppAuth.verify(context, .syncConfig) ||
                      !context.mounted) {
                    return;
                  }
                  final ok = current == .webdav
                      ? await WebDavFormSheet.show(context, ref)
                      : await S3FormSheet.show(context, ref);
                  if (ok != true || !mounted) return;
                  if (ref.read(activeSyncProviderTypeProvider) == current) {
                    await _unlockRemoteKey();
                  }
                },
        ),
        if (conflicts.contains(current.value))
          SettingListTile(
            title: context.l10n.sync.keyConflictTitle,
            subtitle: context.l10n.sync.keyConflictSubtitle,
            leading: Icon(
              LucideIcons.lockKeyhole,
              color: context.theme.colors.error,
            ),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: busy ? null : _unlockRemoteKey,
          ),
        SettingListTile(
          title: context.l10n.sync.testConnection,
          leading: const Icon(LucideIcons.plugZap),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: configured && !busy ? _testConnection : null,
        ),
        if (status.isRunning)
          SettingListTile(
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
          )
        else
          SettingListTile(
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
            onTap: configured && !busy ? _syncNow : null,
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
    if (mounted) {
      ref.read(activeSyncProviderTypeProvider.notifier).select(picked);
    }
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
          onTap: () async {
            if (!await AppAuth.verify(context, .lanSend) || !context.mounted) {
              return;
            }
            const LanSendRoute().push(context);
          },
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
    return MSliverSettingGroup(
      title: context.l10n.sync.encryptionSection,
      children: const [UserKeyTile()],
    );
  }
}

class _AutoSyncSection extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(kvValueProvider(MoodiaryKVs.autoSync));
    final seconds = ref.watch(kvValueProvider(MoodiaryKVs.syncPollInterval));
    return MSliverSettingGroup(
      title: context.l10n.sync.autoSection,
      children: [
        SettingSwitchListTile(
          title: context.l10n.sync.autoSync,
          subtitle: context.l10n.sync.autoSyncSubtitleDetail(
            interval: _fmtInterval(seconds),
          ),
          secondary: const Icon(LucideIcons.refreshCw),
          value: enabled,
          onChanged: (v) => MoodiaryKVs.autoSync.set(v),
        ),
        SettingListTile(
          title: context.l10n.sync.pollInterval,
          subtitle: context.l10n.sync.pollIntervalSubtitle,
          leading: const Icon(LucideIcons.timer),
          trailing: Text(
            _fmtInterval(seconds),
            style: enabled
                ? context.theme.typography.bodyMedium.primary
                : context.theme.typography.bodyMedium.onSurfaceVariant,
          ),
          onTap: enabled ? () => _editPollInterval(context, seconds) : null,
        ),
      ],
    );
  }

  Future<void> _editPollInterval(BuildContext context, int current) async {
    int index = 0;
    for (var i = 0; i < _pollPresets.length; i++) {
      if (_pollPresets[i] <= current) index = i;
    }
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

class _NetworkSection extends ConsumerWidget {
  const _NetworkSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(kvValueProvider(MoodiaryKVs.syncConcurrency));
    return MSliverSettingGroup(
      title: context.l10n.sync.networkSection,
      children: [
        SettingListTile(
          title: context.l10n.sync.concurrency,
          subtitle: context.l10n.sync.concurrencySubtitle,
          leading: const Icon(LucideIcons.server),
          trailing: Text(
            '$value',
            style: context.theme.typography.bodyMedium.primary,
          ),
          onTap: () => _editConcurrency(context, value),
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
