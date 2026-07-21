import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'media_controller.dart';
import 'media_video_viewer.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

/// 媒体库页：顶部「媒体库」标题 + 圆角胶囊筛选条（图片 / 音频 / 视频），按日期倒序
/// 分段浏览。AppBar「清理无用文件」删孤儿媒体。列表用 sliver 懒加载、缩略图按需
/// 降采样，滚动更顺滑。
class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MobileMediaPage();
  }
}

String _typeLabel(BuildContext c, MediaType t) => switch (t) {
  MediaType.image => c.l10n.mediaTypeImage,
  MediaType.audio => c.l10n.mediaTypeAudio,
  MediaType.video => c.l10n.mediaTypeVideo,
};

IconData _typeIcon(MediaType t) => switch (t) {
  MediaType.image => Icons.image_rounded,
  MediaType.audio => Icons.audiotrack_rounded,
  MediaType.video => Icons.movie_rounded,
};

String _countLabel(BuildContext c, MediaType t, int n) => switch (t) {
  MediaType.image => c.l10n.mediaImageCount(n),
  MediaType.audio => c.l10n.mediaAudioCount(n),
  MediaType.video => c.l10n.mediaVideoCount(n),
};

class _MobileMediaPage extends ConsumerStatefulWidget {
  const _MobileMediaPage();

  @override
  ConsumerState<_MobileMediaPage> createState() => _MobileMediaPageState();
}

class _MobileMediaPageState extends ConsumerState<_MobileMediaPage> {
  MediaType _type = MediaType.image;

  // 整页共享一个播放器实例：媒体库任一时刻只播一条音频，避免一屏 N 个播放器。
  late final AudioPlaybackController _audio = AudioPlaybackController();

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mediaTitle),
        actions: [_CleanupButton()],
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          MoodiaryChipBar<MediaType>(
            selected: _type,
            onSelected: (t) => setState(() => _type = t),
            items: [
              for (final t in MediaType.values)
                MoodiaryChipData(
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
              child: _MediaBody(
                key: ValueKey(_type),
                type: _type,
                audioController: _audio,
              ),
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
      tooltip: context.l10n.mediaDeleteUseLessFile,
      icon: const Icon(Icons.cleaning_services_rounded),
      onPressed: () => runMediaCleanup(context, ref),
    );
  }
}

/// 清理无用（孤儿）媒体文件：扫描 → 确认 → 删除。
Future<void> runMediaCleanup(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final notifier = ref.read(mediaCleanupControllerProvider.notifier);

  toast.loading(message: l10n.mediaCleanupScanning);
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
    toast.info(message: l10n.mediaCleanupEmpty);
    return;
  }

  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.mediaCleanupConfirmTitle),
      content: Text(
        l10n.mediaCleanupConfirmMessage(report.count, report.readableSize),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  toast.loading();
  try {
    await notifier.clean(report);
  } catch (_) {
    await toast.dismiss();
    toast.error();
    return;
  }
  // 用调用方仍有效的 ref 刷新媒体库（controller 的 ref 此时可能已被 autoDispose 回收）。
  if (context.mounted) ref.invalidate(mediaDiariesProvider);
  await toast.dismiss();
  toast.success(message: l10n.mediaCleanupDone(report.count));
}

/// 3 列网格的常量（内边距 / 间距 / 列数），用于按屏宽算出缩略图降采样宽度。
const double _kGridPadding = 12;
const double _kGridSpacing = 4;
const int _kGridColumns = 3;

class _MediaBody extends ConsumerWidget {
  final MediaType type;
  final AudioPlaybackController audioController;

  const _MediaBody({
    super.key,
    required this.type,
    required this.audioController,
  });

  /// 按实际单元格宽度算出缩略图解码宽度（像素），避免整图解码——大图列表卡顿主因。
  int _thumbCacheWidth(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final cell =
        (width - _kGridPadding * 2 - _kGridSpacing * (_kGridColumns - 1)) /
        _kGridColumns;
    return (cell * dpr).round();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mediaDiariesProvider(type: type);
    final async = ref.watch(provider);
    return async.buildLoading(
      data: (diaries) {
        final group = buildMediaGroup(diaries, type);
        if (group.isEmpty) return _Empty();
        final cacheWidth = _thumbCacheWidth(context);
        return MoodiaryRefresh(
          onLoadMore: () => ref.read(provider.notifier).loadMore(),
          onRefresh: () => ref.read(provider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              for (final date in group.dates) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    date: date,
                    count: group.groups[date]!.length,
                    type: type,
                  ),
                ),
                _MediaSliver(
                  type: type,
                  names: group.groups[date]!,
                  cacheWidth: cacheWidth,
                  audioController: audioController,
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final DateTime date;
  final int count;
  final MediaType type;

  const _SectionHeader({
    required this.date,
    required this.count,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kGridPadding, 10, _kGridPadding, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              TimeUtil.fullDate(date),
              style: context.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _countLabel(context, type, count),
            style: context.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个日期分段的媒体：图片 / 视频用 [SliverGrid]（cell 级懒加载），音频用 [SliverList]。
class _MediaSliver extends StatelessWidget {
  final MediaType type;
  final List<String> names;
  final int cacheWidth;
  final AudioPlaybackController audioController;

  const _MediaSliver({
    required this.type,
    required this.names,
    required this.cacheWidth,
    required this.audioController,
  });

  @override
  Widget build(BuildContext context) {
    if (type == MediaType.audio) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: _kGridPadding),
        sliver: SliverList.separated(
          itemCount: names.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          // 按文件名 key，实时插入/重排时移动元素而非改数据（不错位）；卡片仅绑定共享控制器。
          itemBuilder: (context, i) => AudioTile(
            key: ValueKey(names[i]),
            controller: audioController,
            path: FileUtil.getRealPath('audio', names[i]),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: _kGridPadding),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _kGridColumns,
          mainAxisSpacing: _kGridSpacing,
          crossAxisSpacing: _kGridSpacing,
        ),
        itemCount: names.length,
        // 按文件名 key：实时插入/重排时移动已解码的缩略图，避免闪成邻格旧图。
        itemBuilder: (context, i) => switch (type) {
          MediaType.image => _ImageTile(
            key: ValueKey(names[i]),
            names: names,
            index: i,
            cacheWidth: cacheWidth,
          ),
          MediaType.video => _VideoTile(
            key: ValueKey(names[i]),
            name: names[i],
            cacheWidth: cacheWidth,
          ),
          MediaType.audio => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// 缩略图基座：圆角 + 占位底色 + 解码后淡入，减少滚动时的「弹出」突兀感。
class _Thumb extends StatelessWidget {
  final ImageProvider image;
  final Widget? overlay;

  const _Thumb({required this.image, this.overlay});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppBorderRadius.smallBorderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: context.colorScheme.surfaceContainerHighest),
          Image(
            image: image,
            fit: BoxFit.cover,
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
              Icons.broken_image_outlined,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          ?overlay,
        ],
      ),
    );
  }
}

/// 媒体库图片 Hero tag 前缀（与 [MoodiaryImageBrowser] 的约定：`'$prefix-<路径>'`）。
const String _kImageHeroPrefix = 'media';

class _ImageTile extends StatelessWidget {
  final List<String> names;
  final int index;
  final int cacheWidth;

  const _ImageTile({
    super.key,
    required this.names,
    required this.index,
    required this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final path = FileUtil.getRealPath('image', names[index]);
    return GestureDetector(
      onTap: () => MoodiaryImageBrowser.show(
        context,
        images: [
          for (final name in names) FileUtil.getRealPath('image', name),
        ],
        initialIndex: index,
        heroPrefix: _kImageHeroPrefix,
        // 与网格缩略图同解码宽度 → 同缓存键，浏览器加载态直接命中缩略图。
        placeholderCacheWidth: cacheWidth,
      ),
      child: Hero(
        tag: '$_kImageHeroPrefix-$path',
        child: _Thumb(
          image: ResizeImage(FileImage(File(path)), width: cacheWidth),
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final String name;
  final int cacheWidth;

  const _VideoTile({super.key, required this.name, required this.cacheWidth});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => MediaVideoViewer.show(context, name: name),
      child: _Thumb(
        image: ResizeImage(
          FileImage(File(FileUtil.getRealPath('thumbnail', name))),
          width: cacheWidth,
        ),
        overlay: const Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: BoxDecoration(color: Colors.black26)),
            Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
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
    final scheme = context.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.boxArchive,
            size: 64,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.mediaEmpty,
            style: context.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
