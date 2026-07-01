import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary/feature/media/application/media_controller.dart';
import 'package:moodiary/feature/media/presentation/widget/media_image_viewer.dart';
import 'package:moodiary/feature/media/presentation/widget/media_video_viewer.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

/// 媒体库页：按类型（图片 / 音频 / 视频）分类、按日期倒序分段浏览，顶部分段控件切换。
/// AppBar「清理无用文件」删孤儿媒体。
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

class _MobileMediaPage extends ConsumerStatefulWidget {
  const _MobileMediaPage();

  @override
  ConsumerState<_MobileMediaPage> createState() => _MobileMediaPageState();
}

class _MobileMediaPageState extends ConsumerState<_MobileMediaPage> {
  final PageController _pageController = PageController();
  MediaType _type = MediaType.image;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTypeSelected(MediaType next) {
    if (next == _type) return;
    setState(() => _type = next);
    _pageController.animateToPage(
      next.index,
      duration: Durations.medium2,
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    final next = MediaType.values[index];
    if (next == _type) return;
    setState(() => _type = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        actions: [_CleanupButton()],
        // FittedBox 兜底：窄屏 / 大字号下 3 段图标+文字过宽时整体缩放，避免溢出。
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: SegmentedButton<MediaType>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: context.textTheme.labelLarge,
            ),
            segments: [
              for (final t in MediaType.values)
                ButtonSegment(
                  value: t,
                  icon: Icon(_typeIcon(t)),
                  label: Text(_typeLabel(context, t)),
                ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) =>
                _onTypeSelected(selection.first),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [for (final t in MediaType.values) _MediaBody(type: t)],
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

/// 清理无用（孤儿）媒体文件：扫描 → 确认 → 删除。桌面端 AppBar 与移动端玻璃底栏共用。
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

class _MediaBody extends ConsumerWidget {
  final MediaType type;

  const _MediaBody({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mediaDiariesProvider(type: type);
    final async = ref.watch(provider);
    return async.buildLoading(
      data: (diaries) {
        final group = buildMediaGroup(diaries, type);
        if (group.isEmpty) return _Empty();
        return MoodiaryRefresh(
          onLoading: () => ref.read(provider.notifier).loadMore(),
          onRefresh: () => ref.read(provider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            itemCount: group.dates.length,
            itemBuilder: (context, i) {
              final date = group.dates[i];
              return _SectionByDate(
                date: date,
                type: type,
                names: group.groups[date]!,
              );
            },
          ),
        );
      },
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

class _SectionByDate extends StatelessWidget {
  final DateTime date;
  final MediaType type;
  final List<String> names;

  const _SectionByDate({
    required this.date,
    required this.type,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              DateFormat.yMMMMEEEEd().format(date),
              style: context.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
          ),
          switch (type) {
            MediaType.image => _ImageGrid(names: names),
            MediaType.video => _VideoGrid(names: names),
            MediaType.audio => _AudioList(names: names),
          },
        ],
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final List<String> names;

  const _ImageGrid({required this.names});

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: names.length,
      itemBuilder: (context, i) {
        return GestureDetector(
          onTap: () => MediaImageViewer.show(
            context,
            names: names,
            initialIndex: i,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: ResizeImage(
                  FileImage(File(FileUtil.getRealPath('image', names[i]))),
                  width: (160 * pixelRatio).toInt(),
                ),
                fit: BoxFit.cover,
              ),
              borderRadius: AppBorderRadius.smallBorderRadius,
            ),
          ),
        );
      },
    );
  }
}

class _VideoGrid extends StatelessWidget {
  final List<String> names;

  const _VideoGrid({required this.names});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: names.length,
      itemBuilder: (context, i) {
        final thumbPath = FileUtil.getRealPath('thumbnail', names[i]);
        return GestureDetector(
          onTap: () => MediaVideoViewer.show(context, name: names[i]),
          child: ClipRRect(
            borderRadius: AppBorderRadius.smallBorderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(thumbPath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.movie_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black26),
                ),
                const Center(
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
      },
    );
  }
}

class _AudioList extends StatelessWidget {
  final List<String> names;

  const _AudioList({required this.names});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < names.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == names.length - 1 ? 0 : 8),
            child: AudioPlayerComponent(
              path: FileUtil.getRealPath('audio', names[i]),
            ),
          ),
      ],
    );
  }
}
