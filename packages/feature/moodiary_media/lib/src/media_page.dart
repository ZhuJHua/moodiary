import 'package:fast_image/fast_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'media_controller.dart';
import 'media_layout.dart';
import 'media_video_viewer.dart';

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MobileMediaPage();
  }
}

String _typeLabel(BuildContext c, MediaType t) => switch (t) {
  .image => c.l10n.media.typeImage,
  .audio => c.l10n.common.audio,
  .video => c.l10n.common.video,
};

IconData _typeIcon(MediaType t) => switch (t) {
  .image => LucideIcons.image,
  .audio => LucideIcons.music,
  .video => LucideIcons.film,
};

String _countLabel(BuildContext c, MediaType t, int n) => switch (t) {
  .image => c.l10n.media.imageCount(count: n),
  .audio => c.l10n.media.audioCount(count: n),
  .video => c.l10n.media.videoCount(count: n),
};

class _MobileMediaPage extends ConsumerStatefulWidget {
  const _MobileMediaPage();

  @override
  ConsumerState<_MobileMediaPage> createState() => _MobileMediaPageState();
}

class _MobileMediaPageState extends ConsumerState<_MobileMediaPage> {
  MediaType _type = .image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.media.title),
        actions: [_CleanupButton()],
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          MChipBar<MediaType>(
            selected: _type,
            onSelected: (t) => setState(() => _type = t),
            items: [
              for (final t in MediaType.values)
                MChipData(
                  value: t,
                  label: _typeLabel(context, t),
                  icon: _typeIcon(t),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: AnimatedSwitcher(
              duration: Durations.short3,
              child: _MediaBody(key: ValueKey(_type), type: _type),
            ),
          ),
        ],
      ),
    );
  }
}

class _CleanupButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: context.l10n.media.deleteUseLessFile,
      icon: const Icon(LucideIcons.brushCleaning),
      onPressed: () => runMediaCleanup(context, ref),
    );
  }
}

Future<void> runMediaCleanup(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final notifier = ref.read(mediaCleanupControllerProvider.notifier);

  toast.loading(message: l10n.media.cleanupScanning);
  final MediaCleanupReport report;
  try {
    report = await notifier.scan();
  } catch (_) {
    await toast.dismiss();
    toast.error();
    return;
  }
  await toast.dismiss();

  if (report.isEmpty) {
    toast.info(message: l10n.media.cleanupEmpty);
    return;
  }

  if (!context.mounted) return;
  final confirmed = await MAlert.confirm(
    context,
    title: l10n.media.cleanupConfirmTitle,
    message: l10n.media.cleanupConfirmMessage(
      count: report.count,
      size: report.readableSize,
    ),
    isDestructive: true,
  );
  if (!confirmed) return;

  toast.loading();
  try {
    await notifier.clean(report);
  } catch (_) {
    await toast.dismiss();
    toast.error();
    return;
  }
  if (context.mounted) ref.invalidate(mediaItemsProvider);
  await toast.dismiss();
  toast.success(message: l10n.media.cleanupDone(count: report.count));
}

const double _kGridPadding = 12;
const double _kGridSpacing = 4;
const int _kGridColumns = 3;
const double _kAudioTileExtent = 66;
const double _kAudioSpacing = 8;

class _MediaBody extends ConsumerWidget {
  final MediaType type;

  const _MediaBody({super.key, required this.type});

  double _headerExtent(BuildContext context) =>
      18 + MediaQuery.textScalerOf(context).scale(24);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mediaItemsProvider(type: type);
    final async = ref.watch(provider);
    return async.buildLoading(
      data: (items) {
        final flat = MediaFlat.of(items);
        if (flat.isEmpty) return _Empty();
        final audio = type == .audio;
        return MRefresh(
          onLoadMore: () => ref.read(provider.notifier).loadMore(),
          onRefresh: () => ref.read(provider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              SliverPadding(
                padding: const .symmetric(horizontal: _kGridPadding),
                sliver: SliverGrid(
                  gridDelegate: GroupedGridDelegate(
                    entries: flat.entries,
                    columns: audio ? 1 : _kGridColumns,
                    spacing: audio ? _kAudioSpacing : _kGridSpacing,
                    headerExtent: _headerExtent(context),
                    tileMainExtent: audio ? _kAudioTileExtent : null,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _buildEntry(flat, i),
                    childCount: flat.entries.length,
                    findChildIndexCallback: flat.indexOfKey,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 24 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEntry(MediaFlat flat, int i) {
    final key = flat.keys[i];
    switch (flat.entries[i]) {
      case MediaHeader(:final group):
        return _SectionHeader(
          key: key,
          date: flat.dates[group],
          count: flat.groups[group].length,
          type: type,
        );
      case MediaCell(:final group, :final index):
        final names = flat.groups[group];
        return switch (type) {
          .image => _ImageTile(key: key, names: names, index: index),
          .video => _VideoTile(key: key, name: names[index]),
          .audio => _AudioTile(
            key: key,
            name: names[index],
            date: flat.dates[group],
          ),
        };
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final DateTime date;
  final int count;
  final MediaType type;

  const _SectionHeader({
    super.key,
    required this.date,
    required this.count,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const .only(top: 10, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              TimeFormat.fullDate(date),
              maxLines: 1,
              overflow: .ellipsis,
              style: theme.typography.titleSmall.emphasized.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _countLabel(context, type, count),
            style: theme.typography.labelSmall.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

final Set<String> _backfillAttempted = {};

Future<void> _backfillChain = Future.value();

void _scheduleBackfill(String name) {
  if (!_backfillAttempted.add(name)) return;
  _backfillChain = _backfillChain
      .then((_) => _backfillMediaInfo(name))
      .catchError(
        (Object e, StackTrace s) =>
            logger.e('audio backfill failed: $name', error: e, stackTrace: s),
      );
}

Future<void> _backfillMediaInfo(String name) async {
  final duration = await probeAudioDuration(
    AppFiles.getRealPath('audio', name),
  );
  if (duration == null) return;
  final existing = await getIt<MediaInfoRepository>().getMediaInfoByFileName(
    name,
  );
  if (existing?.durationMs != null) return;
  await getIt<MediaInfoRepository>().insertAMediaInfo(
    MediaInfo(
      fileName: name,
      name: existing?.name,
      durationMs: duration.inMilliseconds,
      lastModified:
          existing?.lastModified ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ),
  );
}

class _AudioTile extends ConsumerWidget {
  final String name;
  final DateTime date;

  const _AudioTile({super.key, required this.name, required this.date});

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    MediaInfo? info,
  ) async {
    final action = await MMenu.show<_AudioTileAction>(
      anchorContext: context,
      entries: [
        MMenuEntry(
          value: .rename,
          label: context.l10n.media.rename,
          icon: LucideIcons.pencilLine,
        ),
      ],
    );
    if (action != .rename || !context.mounted) return;
    final input = await MAlert.prompt(
      context,
      title: context.l10n.media.rename,
      initialValue: info?.name ?? '',
      hintText: context.l10n.common.name,
    );
    if (input == null) return;
    await ref
        .read(mediaInfoControllerProvider.notifier)
        .upsertMediaInfo(
          MediaInfo(
            fileName: name,
            name: input.isEmpty ? null : input,
            durationMs: info?.durationMs,
            lastModified: .timestamp(),
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final scheme = theme.colors;
    final info = ref.watch(mediaInfoByFileNameProvider(name));
    final infoReady = ref.watch(mediaInfoControllerProvider).hasValue;
    if (infoReady && info?.durationMs == null) {
      _scheduleBackfill(name);
    }
    final displayName = info?.name ?? context.l10n.common.audio;
    final durationMs = info?.durationMs;
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.largeBorderRadius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: MInkWell(
        shape: const RoundedRectangleBorder(
          borderRadius: AppBorderRadius.largeBorderRadius,
        ),
        onTap: () => MAudioPlayerPage.showByName(
          context,
          name: name,
          title: displayName,
          subtitle: TimeFormat.fullDate(date),
          knownDuration: durationMs == null
              ? null
              : Duration(milliseconds: durationMs),
        ),
        onLongPress: () => _rename(context, ref, info),
        child: Padding(
          padding: const .all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: AppBorderRadius.smallBorderRadius,
                ),
                child: Icon(
                  LucideIcons.music,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: theme.typography.bodyMedium.emphasized.onSurface,
                ),
              ),
              if (durationMs != null) ...[
                const SizedBox(width: 8),
                Text(
                  TimeFormat.mediaDuration(Duration(milliseconds: durationMs)),
                  style: theme.typography.labelSmall.onSurfaceVariant.copyWith(
                    fontFeatures: const [.tabularFigures()],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AudioTileAction { rename }

class _Thumb extends StatelessWidget {
  final ImageProvider image;
  final Widget? overlay;

  const _Thumb({required this.image, this.overlay});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppBorderRadius.smallBorderRadius,
      child: Stack(
        fit: .expand,
        children: [
          ColoredBox(color: context.theme.colors.surfaceContainerHighest),
          Image(
            image: image,
            fit: .cover,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSync) {
              if (wasSync) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: Durations.short2,
                child: child,
              );
            },
            errorBuilder: (context, _, _) => Icon(
              LucideIcons.imageOff,
              color: context.theme.colors.onSurfaceVariant,
            ),
          ),
          ?overlay,
        ],
      ),
    );
  }
}

const String _kImageHeroPrefix = 'media';

class _ImageTile extends StatelessWidget {
  final List<String> names;
  final int index;

  const _ImageTile({super.key, required this.names, required this.index});

  @override
  Widget build(BuildContext context) {
    final path = AppFiles.getRealPath('image', names[index]);
    return GestureDetector(
      onTap: () => MImageBrowser.show(
        context,
        images: [for (final name in names) AppFiles.getRealPath('image', name)],
        initialIndex: index,
        heroPrefix: _kImageHeroPrefix,
        placeholderTier: .s,
      ),
      child: Hero(
        tag: '$_kImageHeroPrefix-$path',
        child: _Thumb(image: FastImage(path, tier: .s)),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final String name;

  const _VideoTile({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return GestureDetector(
      onTap: () => MediaVideoViewer.show(context, name: name),
      child: _Thumb(
        // 海报走 decodeWidth 而非 tier：走 tier 会被孤儿扫描当 stale 派生物删掉。
        image: FastImage(
          AppFiles.getRealPath('thumbnail', name),
          decodeWidth: FastImageTier.s.width,
        ),
        overlay: Stack(
          fit: .expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.scrim.withValues(alpha: 0.26),
              ),
            ),
            Center(
              child: Icon(
                LucideIcons.circlePlay,
                color: scheme.onInverseSurface,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(
            LucideIcons.packageOpen,
            size: 64,
            color: theme.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.media.empty,
            style: theme.typography.bodyMedium.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
