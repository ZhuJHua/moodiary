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

/// 媒体库页：顶部「媒体库」标题 + 圆角胶囊筛选条（图片 / 音频 / 视频），按日期倒序
/// 分段浏览。AppBar「清理无用文件」删孤儿媒体。整个列表一条 sliver（[GroupedGridDelegate]，
/// 标题 + 格子同一序列，可见范围二分定位）、按媒体文件分页、格子走档位缩略图。
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

/// 清理无用（孤儿）媒体文件：扫描 → 确认 → 删除。
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
  // 用调用方仍有效的 ref 刷新媒体库（controller 的 ref 此时可能已被 autoDispose 回收）。
  if (context.mounted) ref.invalidate(mediaItemsProvider);
  await toast.dismiss();
  toast.success(message: l10n.media.cleanupDone(count: report.count));
}

/// 网格常量：内边距 / 间距 / 列数；音频卡片固定高。
const double _kGridPadding = 12;
const double _kGridSpacing = 4;
const int _kGridColumns = 3;
const double _kAudioTileExtent = 66;
const double _kAudioSpacing = 8;

class _MediaBody extends ConsumerWidget {
  final MediaType type;

  const _MediaBody({super.key, required this.type});

  /// 标题行固定高（内边距 10 + 8 + 一行 titleSmall），随系统字号缩放。
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
              // 整个列表一条 sliver：标题与格子都是它的 child，可见范围二分定位，
              // 不再是每个日期两条 sliver、viewport 每帧顺序问一遍。
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
                    // 按 key 找回已建 element：插入 / 删除后其它格子不重建、不闪图。
                    findChildIndexCallback: flat.indexOfKey,
                  ),
                ),
              ),
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

/// 会话内已尝试过懒补行的文件名，避免探测失败的历史音频（ADTS 裸流）反复重试。
final Set<String> _backfillAttempted = {};

/// 探测串行链：升级用户整页音频都缺行，build 里逐 tile 触发；`probeAudioDuration`
/// 每次 `Isolate.run` 起新 isolate，不串行的话快速滚动一屏能同时起几十个。
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

/// 历史音频懒补行：没有 MediaInfo 行（或行内缺时长）时后台探测一次时长写库。
/// 探测不到（历史 Android 录音）就不落行——没有可存的事实，改名时再建行。
///
/// LWW 纪律：时长是派生缓存，**不得携带「现在」时钟**，否则会在 LWW 上压过
/// 远端带用户命名的行（新装机 / pull 失败窗口下把名字全网擦掉）。无行时落
/// epoch 0——任何真实用户写入都能压过它；已有行只补时长、保留原 lastModified
/// ——不推进时钟就不会覆盖任何人（其它设备各自本地探测即可）。
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
    // 控制器就绪前 provider 对所有 tile 都给 null，此时触发探测全是浪费
    // （行里往往已有时长）；等首次加载完成后再按真实缺口补。
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
        // 与网格缩略图同档位 → 同缓存键，看图页加载态直接命中缩略图。
        placeholderTier: .s,
      ),
      child: Hero(
        tag: '$_kImageHeroPrefix-$path',
        // 网格格子宽随屏宽 / 折叠态变，缓存键只认档位，展开过程中不重载。
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
        // 海报本身就是 1280 宽的 JPEG，不走档位：派生物目录只按 image 目录的名字对账，
        // thumbnail- 前缀的档位会被孤儿扫描当 stale 删掉。夹到 512 解即可，键仍稳定。
        image: FastImage(
          AppFiles.getRealPath('thumbnail', name),
          decodeWidth: FastImageTier.s.width,
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
            context.l10n.media.empty,
            style: theme.typography.bodyMedium.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
