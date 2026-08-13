import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'media_controller.dart';
import 'media_video_viewer.dart';

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
  .image => c.l10n.mediaTypeImage,
  .audio => c.l10n.mediaTypeAudio,
  .video => c.l10n.mediaTypeVideo,
};

IconData _typeIcon(MediaType t) => switch (t) {
  .image => LucideIcons.image,
  .audio => LucideIcons.music,
  .video => LucideIcons.film,
};

String _countLabel(BuildContext c, MediaType t, int n) => switch (t) {
  .image => c.l10n.mediaImageCount(n),
  .audio => c.l10n.mediaAudioCount(n),
  .video => c.l10n.mediaVideoCount(n),
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
        title: Text(context.l10n.mediaTitle),
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
      tooltip: context.l10n.mediaDeleteUseLessFile,
      icon: const Icon(LucideIcons.brushCleaning),
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
  final confirmed = await MAlert.confirm(
    context,
    title: l10n.mediaCleanupConfirmTitle,
    message: l10n.mediaCleanupConfirmMessage(report.count, report.readableSize),
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

  const _MediaBody({super.key, required this.type});

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
        return MRefresh(
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
                  date: date,
                  names: group.groups[date]!,
                  cacheWidth: cacheWidth,
                ),
              ],
              // 底栏悬浮，最后一屏得自己让出那条带 —— 根壳把带高折进了 padding.bottom。
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
    final theme = context.theme;
    return Padding(
      padding: const .fromLTRB(_kGridPadding, 10, _kGridPadding, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              TimeFormat.fullDate(date),
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

/// 单个日期分段的媒体：图片 / 视频用 [SliverGrid]（cell 级懒加载），音频用 [SliverList]。
class _MediaSliver extends StatelessWidget {
  final MediaType type;
  final DateTime date;
  final List<String> names;
  final int cacheWidth;

  const _MediaSliver({
    required this.type,
    required this.date,
    required this.names,
    required this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (type == .audio) {
      return SliverPadding(
        padding: const .symmetric(horizontal: _kGridPadding),
        sliver: SliverList.separated(
          itemCount: names.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          // 按文件名 key，实时插入/重排时移动元素而非改数据（不错位）。
          itemBuilder: (context, i) =>
              _AudioTile(key: ValueKey(names[i]), name: names[i], date: date),
        ),
      );
    }
    return SliverPadding(
      padding: const .symmetric(horizontal: _kGridPadding),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _kGridColumns,
          mainAxisSpacing: _kGridSpacing,
          crossAxisSpacing: _kGridSpacing,
        ),
        itemCount: names.length,
        // 按文件名 key：实时插入/重排时移动已解码的缩略图，避免闪成邻格旧图。
        itemBuilder: (context, i) => switch (type) {
          .image => _ImageTile(
            key: ValueKey(names[i]),
            names: names,
            index: i,
            cacheWidth: cacheWidth,
          ),
          .video => _VideoTile(
            key: ValueKey(names[i]),
            name: names[i],
            cacheWidth: cacheWidth,
          ),
          .audio => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// 会话内已尝试过懒补行的文件名，避免探测失败的历史音频（ADTS 裸流）反复重试。
final Set<String> _backfillAttempted = {};

/// 历史音频懒补行：没有 MediaInfo 行（或行内缺时长）时后台探测一次时长写库。
/// 探测不到（历史 Android 录音）就不落行——没有可存的事实，改名时再建行。
///
/// LWW 纪律：时长是派生缓存，**不得携带「现在」时钟**，否则会在 LWW 上压过
/// 远端带用户命名的行（新装机 / pull 失败窗口下把名字全网擦掉）。无行时落
/// epoch 0——任何真实用户写入都能压过它；已有行只补时长、保留原 lastModified
/// ——不推进时钟就不会覆盖任何人（其它设备各自本地探测即可）。
Future<void> _backfillMediaInfo(String name) async {
  if (!_backfillAttempted.add(name)) return;
  final duration = await probeAudioDuration(
    AppFiles.getRealPath('audio', name),
  );
  if (duration == null) return;
  final existing = await MediaInfoRepository.get().getMediaInfoByFileName(name);
  if (existing?.durationMs != null) return;
  await MediaInfoRepository.get()
      .insertAMediaInfo(
        MediaInfo(
          fileName: name,
          name: existing?.name,
          durationMs: duration.inMilliseconds,
          lastModified:
              existing?.lastModified ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      )
      .run();
}

/// 音频导航卡片：图标 + 名称 + 时长 + 箭头，点击进全屏播放页，长按重命名。
/// 不初始化任何播放器；名称与时长都来自 MediaInfo 表。
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
          label: context.l10n.mediaRename,
          icon: LucideIcons.pencilLine,
        ),
      ],
    );
    if (action != .rename || !context.mounted) return;
    final input = await MAlert.prompt(
      context,
      title: context.l10n.mediaRename,
      initialValue: info?.name ?? '',
      hintText: context.l10n.audioNameLabel,
    );
    if (input == null) return;
    // 清空即回落默认名（存 null，默认名不落盘）；全字段重建、刷 lastModified。
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
    if (info?.durationMs == null) {
      Future.microtask(() => _backfillMediaInfo(name));
    }
    final displayName = info?.name ?? context.l10n.audioDefaultName;
    final durationMs = info?.durationMs;
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.largeBorderRadius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(
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

/// 媒体库图片 Hero tag 前缀（与 [MImageBrowser] 的约定：`'$prefix-<路径>'`）。
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
    final path = AppFiles.getRealPath('image', names[index]);
    return GestureDetector(
      onTap: () => MImageBrowser.show(
        context,
        images: [for (final name in names) AppFiles.getRealPath('image', name)],
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
    final scheme = context.theme.colors;
    return GestureDetector(
      onTap: () => MediaVideoViewer.show(context, name: name),
      child: _Thumb(
        image: ResizeImage(
          FileImage(File(AppFiles.getRealPath('thumbnail', name))),
          width: cacheWidth,
        ),
        // 缩略图底色不可预测：用固定 scrim 压暗，前景按「暗底」配对 onInverseSurface。
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
            context.l10n.mediaEmpty,
            style: theme.typography.bodyMedium.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
