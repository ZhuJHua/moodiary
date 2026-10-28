import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mobile/app/settings/setting_routes.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

import 'storage_bar.dart';
import 'storage_controller.dart';
import 'storage_palette.dart';

String storageSize(num bytes) {
  final value = AppFiles.bytesToUnits(bytes.round());
  return '${value['size']} ${value['unit']}';
}

const _areas = <List<StorageArea>>[
  [.model],
  [.image, .audio, .video],
  [.cache],
  [.database],
  [.other, .logs, .legacyBackups],
  [.font],
  [.file],
];
String _areaName(BuildContext context, int index) => switch (index) {
  0 => context.l10n.storage.model,
  1 => context.l10n.storage.media,
  2 => context.l10n.storage.cache,
  3 => context.l10n.storage.database,
  4 => context.l10n.storage.other,
  5 => context.l10n.storage.font,
  _ => context.l10n.storage.file,
};

String _itemName(BuildContext context, Reclaimable item) => switch (item.kind) {
  .retiredModel => context.l10n.storage.retiredMood,
  .unusedModel => context.l10n.storage.unusedModel,
  .partialDownload => context.l10n.storage.partial,
  .cache => context.l10n.storage.cache,
  .unusedMedia => context.l10n.storage.unusedMedia,
  .legacyBackup => context.l10n.storage.legacy,
};

class _StorageView {
  final StorageDisplay display;
  final List<Reclaimable> items;
  final StorageSelectionState selection;

  const _StorageView(this.display, this.items, this.selection);

  StorageReport? get progress => display.report;
  Set<StorageCleanupKind> get checked => selection.checked;
  bool get cleaning => selection.cleaning;
  bool get hasError => display.error != null;

  /// A rescan behind an already finished report stays quiet: only the first
  /// scan of a visit shows progress.
  bool get scanning => !hasError && progress?.complete != true;
  List<Reclaimable> get selected => selection.selected(items);
  int get selectedBytes => selected.fold(0, (sum, i) => sum + i.bytes);
  int get reclaimableBytes => items
      .where((i) => !i.status.isLoading && !i.status.hasError)
      .fold(0, (sum, i) => sum + i.bytes);
  bool get needsConfirmation => selected.any((i) => i.safety == .careful);
}

class StoragePage extends ConsumerWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(storageDisplayControllerProvider);
    final state = _StorageView(
      display,
      storageReclaimables(
        display.report,
        syncBusy: ref.watch(storageSyncBusyProvider),
      ),
      ref.watch(storageSelectionProvider),
    );
    final items = state.items;
    final selected = state.selected;
    final label = selected.isNotEmpty
        ? context.l10n.storage.clean(size: storageSize(state.selectedBytes))
        : state.scanning &&
              !items.any((i) => !i.status.isLoading && !i.status.hasError)
        ? context.l10n.storage.counting
        : items.isEmpty
        ? context.l10n.storage.allClean
        : context.l10n.storage.nothingSelected;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.storage.title)),
      body: Padding(
        padding: const .symmetric(horizontal: 8),
        child: CustomScrollView(
          slivers: [
            const SliverGap(16),
            _Categories(state: state),
            if (state.hasError)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const .all(16),
                  child: Row(
                    children: [
                      Expanded(child: Text(context.l10n.storage.failed)),
                      TextButton(
                        onPressed: () => ref.invalidate(storageReportProvider),
                        child: Text(context.l10n.storage.retry),
                      ),
                    ],
                  ),
                ),
              ),
            for (final safety in ReclaimSafety.values)
              if (items.any((i) => i.safety == safety))
                MSliverSettingGroup(
                  title: safety == .safe
                      ? context.l10n.storage.recommended
                      : context.l10n.storage.careful,
                  children: [
                    for (final item in items.where((i) => i.safety == safety))
                      _ReclaimTile(item: item, state: state),
                  ],
                ),
            SliverGap(context.safeBottom),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const .fromLTRB(16, 12, 16, 12),
          child: FilledButton(
            onPressed: selected.isEmpty || state.cleaning
                ? null
                : () => _clean(context, ref, state),
            child: state.cleaning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(label),
          ),
        ),
      ),
    );
  }

  Future<void> _clean(
    BuildContext context,
    WidgetRef ref,
    _StorageView state,
  ) async {
    if (state.needsConfirmation) {
      final confirmed = await MSheet.show<bool>(
        context,
        builder: (sheetContext) => MSheetScaffold<bool>(
          title: sheetContext.l10n.storage.confirmTitle(
            count: state.selected.length,
          ),
          actions: [
            MAction(label: sheetContext.l10n.storage.cancel, value: false),
            MAction(
              label: sheetContext.l10n.storage.confirm,
              value: true,
              isPrimary: true,
              isDestructive: true,
            ),
          ],
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              for (final item in state.selected)
                _SheetLine(
                  name: _itemName(sheetContext, item),
                  bytes: item.bytes,
                ),
              const MSettingDivider(),
              _SheetLine(
                name: sheetContext.l10n.storage.total,
                bytes: state.selectedBytes,
              ),
              const SizedBox(height: 16),
              MNoticeItem(
                icon: LucideIcons.triangleAlert,
                title: sheetContext.l10n.storage.warning(
                  names: state.selected
                      .where((i) => i.safety == .careful)
                      .map((i) => _itemName(sheetContext, i))
                      .join(sheetContext.l10n.storage.listSeparator),
                ),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    try {
      final freed = await ref.read(storageSelectionProvider.notifier).clean();
      toast.success(message: l10n.storage.freed(size: storageSize(freed)));
    } catch (_) {
      toast.error(message: l10n.storage.cleanFailed);
    }
  }
}

class _Overview extends StatelessWidget {
  final _StorageView state;
  const _Overview({required this.state});
  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final progress = state.progress;
    final values = [
      for (final areas in _areas)
        areas.fold(0, (sum, a) => sum + (progress?.bytes[a] ?? 0)).toDouble(),
    ];
    final current = progress == null
        ? 0
        : _areas.indexWhere((areas) => areas.contains(progress.area));
    return Padding(
      padding: const .all(16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            crossAxisAlignment: .end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      context.l10n.storage.used,
                      style: theme.typography.bodySmall.onSurfaceVariant,
                    ),
                    _AnimatedSize(
                      bytes: progress?.total ?? 0,
                      style:
                          theme.typography.headlineMedium.emphasized.onSurface,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: .end,
                children: [
                  Text(
                    context.l10n.storage.reclaimable,
                    style: theme.typography.bodySmall.onSurfaceVariant,
                  ),
                  _AnimatedSize(
                    bytes: state.reclaimableBytes,
                    style: theme.typography.titleMedium.emphasized.primary,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          StorageBar(
            values: values,
            colors: StoragePalette.of(context),
            scanning: state.scanning,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (state.scanning) const _PulseDot(),
              Expanded(
                child: Text(
                  state.scanning
                      ? context.l10n.storage.scanning(
                          area: _areaName(context, current < 0 ? 4 : current),
                        )
                      : state.hasError
                      ? context.l10n.storage.failed
                      : context.l10n.storage.complete,
                  style: theme.typography.labelSmall.onSurfaceVariant,
                ),
              ),
              if (state.scanning)
                Text(
                  context.l10n.storage.fileCount(count: progress?.files ?? 0),
                  style: theme.typography.labelSmall.onSurfaceVariant.copyWith(
                    fontFeatures: const [.tabularFigures()],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  final _StorageView state;
  const _Categories({required this.state});

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    // 总览和分类同属一组：总览是第一行，分隔线由分组统一画
    return MSliverSettingGroup(
      children: [
        _Overview(state: state),
        for (var i = 0; i < _areas.length; i++)
          _Category(
            index: i,
            bytes: _areas[i].fold(
              0,
              (sum, a) => sum + (progress?.bytes[a] ?? 0),
            ),
            done: progress != null && _areas[i].every(progress.done.contains),
            reclaimable: state.items
                .where(
                  (item) => !item.status.isLoading && !item.status.hasError,
                )
                .fold(0, (sum, item) => sum + item.bytesIn(_areas[i])),
          ),
      ],
    );
  }
}

class _Category extends ConsumerWidget {
  final int index;
  final int bytes;
  final int reclaimable;
  final bool done;
  const _Category({
    required this.index,
    required this.bytes,
    required this.done,
    required this.reclaimable,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = switch (index) {
      0 => const ServicesRoute(),
      1 => const MediaRoute(),
      5 => const FontRoute(),
      _ => null,
    };
    // 可清理量叠在尺寸正下方，两行都右对齐；两行小字仍在单行行高内，行高不跳
    final size = Column(
      mainAxisSize: .min,
      crossAxisAlignment: .end,
      children: [
        _AnimatedSize(
          bytes: bytes,
          suffix: done ? '' : '…',
          style: context.theme.typography.bodySmall.primary,
        ),
        if (reclaimable > 0)
          Text(
            context.l10n.storage.cleanable(size: storageSize(reclaimable)),
            style: context.theme.typography.labelSmall.onSurfaceVariant
                .copyWith(fontFeatures: const [.tabularFigures()]),
          ),
      ],
    );
    return SettingListTile(
      onTap: route == null
          ? null
          : () async {
              await route.push(context);
              if (!context.mounted) return;
              ref.invalidate(storageReportProvider);
            },
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: StoragePalette.of(context)[index],
          borderRadius: .circular(context.theme.radii.sm),
        ),
      ),
      title: _areaName(context, index),
      trailing: route == null
          ? size
          : Row(
              mainAxisSize: .min,
              spacing: 8,
              children: [
                size,
                Icon(
                  LucideIcons.chevronRight,
                  color: context.theme.colors.onSurfaceVariant,
                ),
              ],
            ),
    );
  }
}

class _ReclaimTile extends ConsumerWidget {
  final Reclaimable item;
  final _StorageView state;
  const _ReclaimTile({required this.item, required this.state});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = item.available && !state.cleaning;
    final parts = [
      storageSize(item.bytes),
      if (item.kind == .retiredModel) context.l10n.storage.noLongerUsed,
      for (final entry in item.counts.entries)
        switch (entry.key) {
          .image => context.l10n.media.imageCount(count: entry.value),
          .audio => context.l10n.media.audioCount(count: entry.value),
          .video => context.l10n.media.videoCount(count: entry.value),
          .file => context.l10n.media.fileCount(count: entry.value),
        },
      if (item.kind == .unusedMedia) context.l10n.storage.irreversible,
    ];
    final subtitle = item.busy
        ? context.l10n.storage.syncing
        : item.status.hasError
        ? context.l10n.storage.failed
        : item.status.isLoading
        ? context.l10n.storage.counting
        : parts.join(' · ');
    return SettingCheckboxListTile(
      title: _itemName(context, item),
      subtitle: subtitle,
      value: state.checked.contains(item.kind),
      onChanged: enabled
          ? (_) => ref.read(storageSelectionProvider.notifier).toggle(item.kind)
          : null,
    );
  }
}

class _SheetLine extends StatelessWidget {
  final String name;
  final int bytes;
  const _SheetLine({required this.name, required this.bytes});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(name)),
        const SizedBox(width: 12),
        Text(
          storageSize(bytes),
          style: context.theme.typography.bodyMedium.onSurface.copyWith(
            fontFeatures: const [.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _AnimatedSize extends StatelessWidget {
  final int bytes;
  final TextStyle style;
  final String suffix;
  const _AnimatedSize({
    required this.bytes,
    required this.style,
    this.suffix = '',
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: bytes.toDouble()),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 350),
    curve: Curves.easeOutCubic,
    builder: (context, value, _) => Text(
      '${storageSize(value)}$suffix',
      style: style.copyWith(fontFeatures: const [.tabularFigures()]),
    ),
  );
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
    lowerBound: 0.25,
    upperBound: 1,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .only(right: 6),
    child: FadeTransition(
      opacity: _controller,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: .circle,
          color: context.theme.colors.onSurfaceVariant,
        ),
      ),
    ),
  );
}
