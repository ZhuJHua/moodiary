import 'package:fast_image/fast_image.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_diary/src/application/diary_stamp.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

const double _kThumbW = 96.0;
const double _kThumbTallW = 56.0;
const double _kThumbH = 72.0;

const double _kTagAreaMax = 116.0;

const int _kMaxCells = 3;
const double _kCellGap = 5.0;

class _Cell {
  final String name;
  final bool isVideo;

  const _Cell(this.name, {this.isVideo = false});

  String get path =>
      AppFiles.getRealPath(isVideo ? 'thumbnail' : 'image', name);
}

List<_Cell> _cellsOf(Diary diary) => [
  for (final n in diary.videoName) _Cell(n, isVideo: true),
  for (final n in diary.imageName) _Cell(n),
];

class DiaryFeedTile extends StatelessWidget {
  final Diary diary;

  final DiarySort sort;
  final Category? category;
  final Place? place;
  final bool showCategoryLabel;
  final DiaryCardSyncState syncState;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  const DiaryFeedTile({
    super.key,
    required this.diary,
    this.sort = .timeDesc,
    this.category,
    this.place,
    this.showCategoryLabel = true,
    this.syncState = .none,
    this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cells = _cellsOf(diary);
    final sideThumb = cells.length == 1 && !cells.first.isVideo;
    final stamp = diaryStampOf(diary, sort);
    final showAudioMark = diary.audioName.isNotEmpty && cells.isNotEmpty;

    return DiaryTileFrame(
      selecting: selecting,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      card: true,
      borderRadius: AppBorderRadius.largeBorderRadius,
      margin: const .symmetric(horizontal: 12),
      padding: const .fromLTRB(12, 12, 12, 12),
      child: sideThumb
          ? _SideThumbRow(
              diary: diary,
              cell: cells.first,
              stamp: stamp,
              showAudioMark: showAudioMark,
              category: category,
              place: place,
              showCategoryLabel: showCategoryLabel,
              syncState: syncState,
            )
          : _StackedColumn(
              diary: diary,
              cells: cells,
              stamp: stamp,
              showAudioMark: showAudioMark,
              category: category,
              place: place,
              showCategoryLabel: showCategoryLabel,
              syncState: syncState,
            ),
    );
  }
}

class _SideThumbRow extends StatelessWidget {
  final Diary diary;
  final DateTime stamp;
  final bool showAudioMark;
  final _Cell cell;
  final Category? category;
  final Place? place;
  final bool showCategoryLabel;
  final DiaryCardSyncState syncState;

  const _SideThumbRow({
    required this.diary,
    required this.stamp,
    required this.showAudioMark,
    required this.cell,
    required this.category,
    required this.place,
    required this.showCategoryLabel,
    required this.syncState,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final ratio = diary.aspect;
    final width = (ratio != null && ratio < 1) ? _kThumbTallW : _kThumbW;

    return Row(
      crossAxisAlignment: .start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              _Headline(diary: diary),
              _Excerpt(diary: diary, maxLines: 2),
              const SizedBox(height: 7),
              _MetaLine(
                diary: diary,
                stamp: stamp,
                showAudioMark: showAudioMark,
                category: category,
                place: place,
                showCategoryLabel: showCategoryLabel,
                syncState: syncState,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const .only(top: 1),
          child: SizedBox(
            width: width,
            height: _kThumbH,
            child: _Thumb(
              cell: cell,
              decodeWidth: (width * dpr).round(),
              radius: const .all(.circular(10)),
              pending: syncState == .syncing,
            ),
          ),
        ),
      ],
    );
  }
}

class _StackedColumn extends StatelessWidget {
  final Diary diary;
  final DateTime stamp;
  final bool showAudioMark;
  final List<_Cell> cells;
  final Category? category;
  final Place? place;
  final bool showCategoryLabel;
  final DiaryCardSyncState syncState;

  const _StackedColumn({
    required this.diary,
    required this.stamp,
    required this.showAudioMark,
    required this.cells,
    required this.category,
    required this.place,
    required this.showCategoryLabel,
    required this.syncState,
  });

  @override
  Widget build(BuildContext context) {
    final hasMedia = cells.isNotEmpty || diary.audioName.isNotEmpty;
    return Column(
      crossAxisAlignment: .start,
      children: [
        _Headline(diary: diary, runInBody: hasMedia),
        if (!hasMedia) _Excerpt(diary: diary, maxLines: 2),
        if (cells.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Strip(cells: cells, pending: syncState == .syncing),
        ] else if (diary.audioName.isNotEmpty) ...[
          const SizedBox(height: 6),
          _AudioBar(count: diary.audioName.length),
        ],
        const SizedBox(height: 7),
        _MetaLine(
          diary: diary,
          stamp: stamp,
          showAudioMark: showAudioMark,
          category: category,
          place: place,
          showCategoryLabel: showCategoryLabel,
          syncState: syncState,
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  final Diary diary;
  final bool runInBody;

  const _Headline({required this.diary, this.runInBody = false});

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography;
    final title = diary.title.trim();
    final body = diary.contentText.preview();

    final mark = WidgetSpan(
      alignment: .middle,
      child: Padding(
        padding: const .only(right: 7),
        child: Container(
          width: 3.5,
          height: 12,
          decoration: BoxDecoration(
            color: diaryMoodColor(diary.mood),
            borderRadius: const .all(.circular(999)),
          ),
        ),
      ),
    );

    if (title.isEmpty) {
      return Text.rich(
        TextSpan(
          children: [
            mark,
            TextSpan(text: body),
          ],
        ),
        maxLines: 1,
        overflow: .ellipsis,
        style: typo.bodyMedium.onSurface,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          mark,
          TextSpan(
            text: title,
            style: typo.titleSmall.emphasized.onSurface.copyWith(height: 1.35),
          ),
          if (runInBody && body.isNotEmpty)
            TextSpan(text: '  $body', style: typo.bodySmall.onSurfaceVariant),
        ],
      ),
      maxLines: 1,
      overflow: .ellipsis,
    );
  }
}

class _Excerpt extends StatelessWidget {
  final Diary diary;
  final int maxLines;

  const _Excerpt({required this.diary, required this.maxLines});

  @override
  Widget build(BuildContext context) {
    final body = diary.contentText.preview();
    if (body.isEmpty || diary.title.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const .only(top: 3),
      child: Text(
        body,
        maxLines: maxLines,
        overflow: .ellipsis,
        style: context.theme.typography.bodySmall.onSurfaceVariant.copyWith(
          height: 1.55,
        ),
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  final List<_Cell> cells;
  final bool pending;

  const _Strip({required this.cells, required this.pending});

  @override
  Widget build(BuildContext context) {
    final show = cells.length > _kMaxCells ? _kMaxCells : cells.length;
    final extra = cells.length - show;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width <= 0) return const SizedBox.shrink();
        final cell = (width - _kCellGap * (_kMaxCells - 1)) / _kMaxCells;
        return SizedBox(
          height: cell * 9 / 16,
          child: Row(
            children: [
              for (var i = 0; i < show; i++) ...[
                if (i > 0) const SizedBox(width: _kCellGap),
                SizedBox(
                  width: cell,
                  child: _Thumb(
                    cell: cells[i],
                    radius: const .all(.circular(10)),
                    moreCount: i == show - 1 && extra > 0 ? extra : 0,
                    pending: pending,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  final _Cell cell;

  final int? decodeWidth;
  final BorderRadius radius;
  final int moreCount;

  final bool pending;

  const _Thumb({
    required this.cell,
    this.decodeWidth,
    required this.radius,
    this.moreCount = 0,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: .expand,
        children: [
          ColoredBox(color: colors.surfaceContainerHighest),
          Image(
            // key 需含 pending：gaplessPlayback 下 Element 复用会先画上一篇的照片
            key: ValueKey('${cell.path}#$pending'),
            // 视频封面不走派生档位，派生物只给原件算
            image: FastImage(
              cell.path,
              tier: cell.isVideo ? null : .s,
              decodeWidth: decodeWidth,
            ),
            fit: .cover,
            gaplessPlayback: true,
            // 重装后媒体文件会被清空而日记还在，没有 errorBuilder 就是一片空白
            errorBuilder: (context, _, _) => pending
                ? const SizedBox.shrink()
                : Icon(LucideIcons.imageOff, color: colors.onSurfaceVariant),
          ),
          if (cell.isVideo) const _VideoScrim(),
          if (moreCount > 0) _MoreOverlay(count: moreCount),
        ],
      ),
    );
  }
}

class _VideoScrim extends StatelessWidget {
  const _VideoScrim();

  @override
  Widget build(BuildContext context) {
    final scrim = context.theme.colors.scrim;
    return Stack(
      fit: .expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: .bottomCenter,
              end: .topCenter,
              colors: [scrim.withValues(alpha: 0.54), Colors.transparent],
              stops: const [0, 0.58],
            ),
          ),
        ),
        Positioned(
          left: 4,
          bottom: 3,
          child: Icon(
            LucideIcons.circlePlay,
            size: 14,
            color: context.theme.onMedia,
          ),
        ),
      ],
    );
  }
}

class _MoreOverlay extends StatelessWidget {
  final int count;

  const _MoreOverlay({required this.count});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.theme.colors.scrim.withValues(alpha: 0.44),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: context.theme.typography.labelLarge.emphasized.onMedia,
        ),
      ),
    );
  }
}

class _AudioBar extends StatelessWidget {
  final int count;

  const _AudioBar({required this.count});

  static const List<double> _pattern = [
    4,
    6,
    8,
    12,
    6,
    4,
    8,
    10,
    5,
    12,
    7,
    4,
    9,
    6,
    11,
    5,
    8,
    4,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      height: 22,
      width: 188,
      padding: const .symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: const .all(.circular(11)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.mic, size: 12, color: colors.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Row(
              mainAxisAlignment: .spaceBetween,
              crossAxisAlignment: .center,
              children: [
                for (final h in _pattern)
                  Container(
                    width: 2,
                    height: h,
                    decoration: BoxDecoration(
                      color: .lerp(colors.outlineVariant, colors.primary, 0.52),
                      borderRadius: const .all(.circular(1)),
                    ),
                  ),
              ],
            ),
          ),
          if (count > 1) ...[
            const SizedBox(width: 6),
            Text(
              '$count',
              style: context.theme.typography.labelSmall.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final Diary diary;
  final DateTime stamp;
  final bool showAudioMark;
  final Category? category;
  final Place? place;
  final bool showCategoryLabel;
  final DiaryCardSyncState syncState;

  const _MetaLine({
    required this.diary,
    required this.stamp,
    required this.showAudioMark,
    required this.category,
    required this.place,
    required this.showCategoryLabel,
    required this.syncState,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final onVariant = colors.onSurfaceVariant;
    final style = context.theme.typography.labelSmall.onSurfaceVariant;
    final weather = diary.weather;
    final placeName = place?.name.trim() ?? '';

    InlineSpan icon(IconData data) => WidgetSpan(
      alignment: .middle,
      child: Padding(
        padding: const .only(right: 3),
        child: Icon(data, size: 11.5, color: onVariant),
      ),
    );
    const dot = TextSpan(text: '  ·  ');

    final spans = <InlineSpan>[
      if (showCategoryLabel && category != null) ...[
        WidgetSpan(
          alignment: .middle,
          child: Padding(
            padding: const .only(right: 4),
            child: _CategoryDot(category: category!),
          ),
        ),
        TextSpan(text: category!.categoryName),
        dot,
      ],
      TextSpan(text: TimeFormat.compactDateTime(stamp)),
      if (showAudioMark) ...[
        dot,
        icon(LucideIcons.mic),
        if (diary.audioName.length > 1)
          TextSpan(text: '${diary.audioName.length}'),
      ],
      if (weather != null) ...[
        dot,
        icon(qweatherIcon(weather.icon) ?? LucideIcons.cloud),
        TextSpan(text: weather.compactText),
      ],
      if (placeName.isNotEmpty) ...[
        dot,
        icon(LucideIcons.mapPin),
        TextSpan(text: placeName),
      ],
    ];

    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(children: spans),
            maxLines: 1,
            overflow: .ellipsis,
            style: style,
          ),
        ),
        if (syncState != .none) ...[
          const SizedBox(width: 6),
          DiarySyncBadge(state: syncState),
        ],
        if (diary.tags.isNotEmpty)
          // 不限宽会把左边 Expanded 压到 0 导致 RenderFlex 溢出
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kTagAreaMax),
            child: Row(
              mainAxisSize: .min,
              children: [
                for (final tag in diary.tags.take(2))
                  Flexible(
                    child: Padding(
                      padding: const .only(left: 7),
                      child: _TagChip(label: tag),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryDot extends StatelessWidget {
  final Category category;

  const _CategoryDot({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: categoryColorOf(colorValue: category.color, id: category.id),
        shape: .circle,
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      '#$label',
      maxLines: 1,
      overflow: .ellipsis,
      softWrap: false,
      style: context.theme.typography.labelSmall.onSurfaceVariant,
    );
  }
}
