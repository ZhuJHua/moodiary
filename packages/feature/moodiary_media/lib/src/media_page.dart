import 'package:fast_image/fast_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'attachment_details.dart';
import 'media_controller.dart';
import 'media_layout.dart';
import 'media_video_viewer.dart';

class MediaPage extends StatefulWidget {
  final MediaType initialType;

  const MediaPage({super.key, this.initialType = .image});

  factory MediaPage.fromRoute(GoRouterState state) => MediaPage(
    initialType: switch (state.params['type']) {
      'image' => .image,
      'video' => .video,
      'audio' => .audio,
      'file' => .file,
      _ => .image,
    },
  );

  @override
  State<MediaPage> createState() => _MediaPageState();
}

const _galleryTypes = [
  MediaType.image,
  MediaType.video,
  MediaType.audio,
  MediaType.file,
];

String _typeLabel(BuildContext c, MediaType t) => switch (t) {
  .image => c.l10n.media.typeImage,
  .audio => c.l10n.common.audio,
  .video => c.l10n.common.video,
  .file => c.l10n.media.typeFile,
};

IconData _typeIcon(MediaType t) => switch (t) {
  .image => LucideIcons.image,
  .audio => LucideIcons.music,
  .video => LucideIcons.film,
  .file => LucideIcons.paperclip,
};

String _countLabel(BuildContext c, MediaType t, int n) => switch (t) {
  .image => c.l10n.media.imageCount(count: n),
  .audio => c.l10n.media.audioCount(count: n),
  .video => c.l10n.media.videoCount(count: n),
  .file => c.l10n.media.fileCount(count: n),
};

class _MediaPageState extends State<MediaPage> {
  bool _opening = false;

  Future<void> _openDetail(MediaDetailRoute route) async {
    if (_opening) return;
    _opening = true;
    try {
      await route.push<void>(context);
    } finally {
      _opening = false;
    }
  }

  late MediaType _type = widget.initialType;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.media.title)),
      body: Column(
        children: [
          const SizedBox(height: 4),
          MChipBar<MediaType>(
            selected: _type,
            onSelected: (type) => setState(() => _type = type),
            items: [
              for (final type in _galleryTypes)
                MChipData(
                  value: type,
                  label: _typeLabel(context, type),
                  icon: _typeIcon(type),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: AnimatedSwitcher(
              duration: Durations.short3,
              child: _MediaBody(
                key: ValueKey(_type),
                type: _type,
                openDetail: _openDetail,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const double _kGridPadding = 12;
const double _kGridSpacing = 4;
const int _kGridColumns = 3;
const double _kListSpacing = 8;

class _MediaBody extends ConsumerWidget {
  final MediaType type;

  final ValueChanged<MediaDetailRoute> openDetail;

  const _MediaBody({super.key, required this.type, required this.openDetail});

  double _headerExtent(BuildContext context) =>
      18 + MediaQuery.textScalerOf(context).scale(24);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mediaItemsProvider(type: type);
    final async = ref.watch(provider);
    return async.buildLoading(
      data: (items) {
        final flat = MediaFlat.of(items);
        if (flat.isEmpty) return _Empty(type: type);
        // 音频和附件是一行一条的列表，媒体其余类型是网格。
        final list = type == .audio || type == .file;
        return MRefresh(
          onLoadMore: () => ref.read(provider.notifier).loadMore(),
          onRefresh: () {
            if (type == .file) ref.invalidate(attachmentSizeProvider);
            return ref.read(provider.notifier).refresh();
          },
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              SliverPadding(
                padding: const .symmetric(horizontal: _kGridPadding),
                sliver: SliverGrid(
                  gridDelegate: GroupedGridDelegate(
                    entries: flat.entries,
                    columns: list ? 1 : _kGridColumns,
                    spacing: list ? _kListSpacing : _kGridSpacing,
                    headerExtent: _headerExtent(context),
                    tileMainExtent: list
                        ? mediaListTileExtent(
                            MediaQuery.textScalerOf(context),
                            context
                                .theme
                                .typography
                                .bodyMedium
                                .emphasized
                                .onSurface,
                            context.theme.typography.bodySmall.onSurfaceVariant,
                          )
                        : null,
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
      case MediaCell(:final group, :final index, :final diaryId):
        final names = flat.groups[group];
        void open() => openDetail(
          MediaDetailRoute(
            type: type.value,
            diaryId: diaryId,
            name: names[index],
            label: flat.labels[group][index],
            date: flat.dates[group].millisecondsSinceEpoch,
          ),
        );
        return switch (type) {
          .image => _ImageTile(key: key, names: names, index: index),
          .video => _VideoTile(key: key, name: names[index]),
          .audio => _AudioTile(
            key: key,
            name: names[index],
            label: flat.labels[group][index],
            onTap: open,
          ),
          .file => _FileTile(
            key: key,
            name: names[index],
            label: flat.labels[group][index],
            onTap: open,
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

class _AudioTile extends ConsumerWidget {
  final String name;
  final String? label;
  final VoidCallback onTap;

  const _AudioTile({
    super.key,
    required this.name,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final scheme = theme.colors;
    final trimmed = label?.trim() ?? '';
    final displayName = trimmed.isEmpty ? context.l10n.common.audio : trimmed;
    final duration = ref.watch(audioDurationProvider(name)).value;
    final durationLabel = duration == null
        ? null
        : TimeFormat.mediaDuration(duration);
    return _ListTile(
      title: displayName,
      leading: Container(
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
      trailing: durationLabel == null
          ? null
          : Text(
              durationLabel,
              style: theme.typography.labelSmall.onSurfaceVariant.tabular,
            ),
      onTap: onTap,
    );
  }
}

class _FileTile extends ConsumerWidget {
  final String name;
  final String? label;

  final VoidCallback onTap;

  const _FileTile({
    super.key,
    required this.name,
    this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimmed = label?.trim() ?? '';
    final displayName = trimmed.isEmpty ? context.l10n.media.typeFile : trimmed;
    final extension = attachmentExtension(displayName, name);
    final size = ref.watch(attachmentSizeProvider(name));
    final subtitle = size.isLoading && !size.hasValue
        ? null
        : attachmentSubtitle(
            extension,
            size.value,
            context.l10n.media.waitingSync,
          );
    return _ListTile(
      title: displayName,
      leading: FileTypeIcon(
        extension,
        size: 36,
        color: context.theme.colors.onSurfaceVariant,
      ),
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

class _ListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget leading;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ListTile({
    required this.title,
    required this.leading,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final shape = RoundedRectangleBorder(
      borderRadius: AppBorderRadius.largeBorderRadius,
      side: BorderSide(color: theme.colors.outlineVariant),
    );
    return Material(
      color: theme.colors.surfaceContainer,
      shape: shape,
      child: MInkWell(
        shape: shape,
        onTap: onTap,
        child: Padding(
          padding: const .all(12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: theme.typography.bodyMedium.emphasized.onSurface,
                    ),
                    if (subtitle case final subtitle?) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style:
                            theme.typography.bodySmall.onSurfaceVariant.tabular,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing case final trailing?) ...[
                const SizedBox(width: 8),
                trailing,
              ],
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: theme.colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  final MediaType type;

  const _Empty({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(_typeIcon(type), size: 64, color: theme.colors.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(switch (type) {
            .file => context.l10n.media.emptyFile,
            .image => context.l10n.media.emptyImage,
            .audio => context.l10n.media.emptyAudio,
            .video => context.l10n.media.emptyVideo,
          }, style: theme.typography.bodyMedium.onSurfaceVariant),
        ],
      ),
    );
  }
}
