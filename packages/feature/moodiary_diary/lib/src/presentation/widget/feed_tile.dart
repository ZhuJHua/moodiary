import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_diary/src/application/diary_stamp.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';

/// 右侧缩略图的固定尺寸。密度全靠它：单图不再占整行，一条带图的日记只有约 85px 高。
const double _kThumbW = 96.0;
const double _kThumbTallW = 56.0;
const double _kThumbH = 72.0;

/// 元信息行右端标签块的宽度上限。超过就让标签自己打省略号，绝不挤爆整行。
const double _kTagAreaMax = 116.0;

/// 横排媒体最多三格，多出来的折成末格上的「+N」。
const int _kMaxCells = 3;
const double _kCellGap = 5.0;

/// 一格媒体：图片或视频（视频取其封面缩略图）。
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

/// 信息流的一条 = 一篇日记。没有左栏、没有卡片，三种形态：
/// 纯文字 / 左文右图（单图）/ 文字在上媒体横排在下（多图或含视频）。
class DiaryFeedTile extends StatelessWidget {
  final Diary diary;

  /// 列表当前的排序方式 —— 元信息行显示的时间戳要跟着它走，否则按「最近修改」
  /// 排序时用户看到的是一列日期无序的条目。
  final DiarySort sort;
  final Category? category;
  final bool showCategoryLabel;
  final DiaryCardSyncState syncState;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  const DiaryFeedTile({
    super.key,
    required this.diary,
    this.sort = DiarySort.timeDesc,
    this.category,
    this.showCategoryLabel = true,
    this.syncState = DiaryCardSyncState.none,
    this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cells = _cellsOf(diary);
    // 恰好一张图（且没有视频）才走左文右图；其余走纵向，媒体在正文下方横排。
    final sideThumb = cells.length == 1 && !cells.first.isVideo;
    final stamp = diaryStampOf(diary, sort);
    // 有图时媒体位让给了图片、波形条不出现，语音只能靠元信息行里的标记。
    final showAudioMark = diary.audioName.isNotEmpty && cells.isNotEmpty;

    return DiaryTileFrame(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      card: true,
      borderRadius: AppBorderRadius.largeBorderRadius,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: sideThumb
          ? _SideThumbRow(
              diary: diary,
              cell: cells.first,
              stamp: stamp,
              showAudioMark: showAudioMark,
              category: category,
              showCategoryLabel: showCategoryLabel,
              syncState: syncState,
              selecting: selecting,
              selected: selected,
            )
          : _StackedColumn(
              diary: diary,
              cells: cells,
              stamp: stamp,
              showAudioMark: showAudioMark,
              category: category,
              showCategoryLabel: showCategoryLabel,
              syncState: syncState,
              selecting: selecting,
              selected: selected,
            ),
    );
  }
}

/// 左文右图：文字列吃满图高，元信息行正好与图片下沿齐平。
class _SideThumbRow extends StatelessWidget {
  final Diary diary;
  final DateTime stamp;
  final bool showAudioMark;
  final _Cell cell;
  final Category? category;
  final bool showCategoryLabel;
  final DiaryCardSyncState syncState;
  final bool selecting;
  final bool selected;

  const _SideThumbRow({
    required this.diary,
    required this.stamp,
    required this.showAudioMark,
    required this.cell,
    required this.category,
    required this.showCategoryLabel,
    required this.syncState,
    required this.selecting,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // aspect 全仓还没有写入方，取不到就按横图给宽度；等比例管线补上后竖图自动收窄。
    final ratio = diary.aspect;
    final width = (ratio != null && ratio < 1) ? _kThumbTallW : _kThumbW;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          // 行高自然取「文字高」与「图高 72」的大者：列表给的是无界高度，
          // 这里不能用 Spacer/Expanded 把元信息顶到底，也不值得为对齐上
          // IntrinsicHeight（每帧多测一遍）。
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Headline(diary: diary),
              _Excerpt(diary: diary, maxLines: 2),
              const SizedBox(height: 7),
              _MetaLine(
                diary: diary,
                stamp: stamp,
                showAudioMark: showAudioMark,
                category: category,
                showCategoryLabel: showCategoryLabel,
                syncState: syncState,
                selecting: selecting,
                selected: selected,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: SizedBox(
            width: width,
            height: _kThumbH,
            child: _Thumb(
              cell: cell,
              cacheWidth: (width * dpr).round(),
              radius: const BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

/// 纯文字 / 多图：文字在上，媒体横排在下。
class _StackedColumn extends StatelessWidget {
  final Diary diary;
  final DateTime stamp;
  final bool showAudioMark;
  final List<_Cell> cells;
  final Category? category;
  final bool showCategoryLabel;
  final DiaryCardSyncState syncState;
  final bool selecting;
  final bool selected;

  const _StackedColumn({
    required this.diary,
    required this.stamp,
    required this.showAudioMark,
    required this.cells,
    required this.category,
    required this.showCategoryLabel,
    required this.syncState,
    required this.selecting,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final hasMedia = cells.isNotEmpty || diary.audioName.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 有媒体压在下面时正文接在标题后跑成同一行，媒体就不额外吃一行。
        _Headline(diary: diary, runInBody: hasMedia),
        if (!hasMedia) _Excerpt(diary: diary, maxLines: 2),
        if (cells.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Strip(cells: cells),
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
          showCategoryLabel: showCategoryLabel,
          syncState: syncState,
          selecting: selecting,
          selected: selected,
        ),
      ],
    );
  }
}

/// 标题行：行首一根心情竖色标（寄生在行内，不占额外行高）。无标题时正文首行顶上来。
class _Headline extends StatelessWidget {
  final Diary diary;
  final bool runInBody;

  const _Headline({required this.diary, this.runInBody = false});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final title = diary.title.trim();
    final body = diary.contentText.preview();
    final theme = context.textTheme;

    final mark = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 7),
        child: Container(
          width: 3.5,
          height: 12,
          decoration: BoxDecoration(
            color: diaryMoodColor(diary.mood),
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
        ),
      ),
    );

    if (title.isEmpty) {
      // 无标题：正文首行当标题位，字重轻一档以示区分。
      return Text.rich(
        TextSpan(
          children: [
            mark,
            TextSpan(text: body),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.bodyMedium?.copyWith(color: scheme.onSurface),
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          mark,
          TextSpan(
            text: title,
            style: theme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (runInBody && body.isNotEmpty)
            TextSpan(
              text: '  $body',
              style: theme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        body,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
          height: 1.55,
        ),
      ),
    );
  }
}

/// 媒体横排：三等分 16:9，第三格叠「+N」。
class _Strip extends StatelessWidget {
  final List<_Cell> cells;

  const _Strip({required this.cells});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
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
                    cacheWidth: (cell * dpr).round(),
                    radius: const BorderRadius.all(Radius.circular(10)),
                    moreCount: i == show - 1 && extra > 0 ? extra : 0,
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
  final int cacheWidth;
  final BorderRadius radius;
  final int moreCount;

  const _Thumb({
    required this.cell,
    required this.cacheWidth,
    required this.radius,
    this.moreCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: scheme.surfaceContainerHighest),
          Image(
            // 按文件名 key：开了 gaplessPlayback，列表重排后复用同一个 Element 会
            // 先画上一篇的照片。
            key: ValueKey(cell.path),
            image: ResizeImage(FileImage(File(cell.path)), width: cacheWidth),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // 重装后媒体文件会被清空而日记还在——没有 errorBuilder 就是一片空白。
            errorBuilder: (context, _, _) => Icon(
              Icons.broken_image_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (cell.isVideo) const _VideoScrim(),
          if (moreCount > 0) _MoreOverlay(count: moreCount),
        ],
      ),
    );
  }
}

/// 视频格：底部一层渐变 + 播放角标。时长没有存进模型（[Diary] 只有文件名），
/// 所以只标「这是视频」，不假装知道有多长。
class _VideoScrim extends StatelessWidget {
  const _VideoScrim();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
              stops: [0, 0.58],
            ),
          ),
        ),
        Positioned(
          left: 4,
          bottom: 3,
          child: Icon(
            Icons.play_circle_fill_rounded,
            size: 14,
            color: Colors.white,
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
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.44)),
      child: Center(
        child: Text(
          '+$count',
          style: context.textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 语音：一条窄横条，不占整格高度。波形是固定条 —— 仓里录音实际是 ADTS AAC，
/// 不去解码取真实包络。
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
    final scheme = context.colorScheme;
    return Container(
      height: 22,
      width: 188,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(11)),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_none_rounded, size: 12, color: scheme.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final h in _pattern)
                  Container(
                    width: 2,
                    height: h,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        scheme.outlineVariant,
                        scheme.primary,
                        0.52,
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(1)),
                    ),
                  ),
              ],
            ),
          ),
          if (count > 1) ...[
            const SizedBox(width: 6),
            Text(
              '$count',
              style: context.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 元信息行：分类 · 时间 · 天气 · 地点 …… 标签靠右，恒定一行。
///
/// 左半组整体 [Expanded]、地点在组内 [Flexible]：不能写成「Flexible(地点) + Spacer()」——
/// 两个 flex 子节点会均分剩余宽度，Spacer 拿到的那一半空着也不让。
class _MetaLine extends StatelessWidget {
  final Diary diary;
  final DateTime stamp;
  final bool showAudioMark;
  final Category? category;
  final bool showCategoryLabel;
  final DiaryCardSyncState syncState;
  final bool selecting;
  final bool selected;

  const _MetaLine({
    required this.diary,
    required this.stamp,
    required this.showAudioMark,
    required this.category,
    required this.showCategoryLabel,
    required this.syncState,
    required this.selecting,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final onVariant = scheme.onSurfaceVariant;
    final style = context.textTheme.labelSmall?.copyWith(color: onVariant);
    final hasWeather = diary.weather.length >= 3;
    final hasPlace =
        diary.position.length >= 3 && diary.position[2].trim().isNotEmpty;

    // 左半组做成**一段文本**而不是一排固定块：Row 里的固定块加起来超宽就会 overflow，
    // 而单行 Text 自带省略号，优先级天然由顺序决定（地点最先被吃掉）。
    InlineSpan icon(IconData data) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 3),
        child: Icon(data, size: 11.5, color: onVariant),
      ),
    );
    const dot = TextSpan(text: '  ·  ');

    final spans = <InlineSpan>[
      if (showCategoryLabel && category != null) ...[
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _CategoryDot(category: category!),
          ),
        ),
        TextSpan(text: category!.categoryName),
        dot,
      ],
      TextSpan(text: TimeFormat.compactDateTime(stamp)),
      // 有图时波形条不出现（媒体位让给了图片），语音就只剩这个标记 —— 不能连它也没有，
      // 否则「配了图又录了音」的日记在信息流里没有任何语音痕迹。
      if (showAudioMark) ...[
        dot,
        icon(Icons.mic_none_rounded),
        if (diary.audioName.length > 1)
          TextSpan(text: '${diary.audioName.length}'),
      ],
      if (hasWeather) ...[
        dot,
        icon(Icons.cloud_outlined),
        TextSpan(text: '${diary.weather[1]}°'),
      ],
      if (hasPlace) ...[
        dot,
        icon(Icons.place_outlined),
        TextSpan(text: diary.position[2]),
      ],
    ];

    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(children: spans),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (syncState != DiaryCardSyncState.none) ...[
          const SizedBox(width: 6),
          DiarySyncBadge(state: syncState),
        ],
        if (selecting) ...[
          const SizedBox(width: 6),
          DiarySelectMark(selected: selected),
        ] else if (diary.tags.isNotEmpty)
          // 标签块整体封顶：它是 Row 里的**非 flex** 子节点，不限宽的话标签有多长
          // 就吃多宽，把左边那段 Expanded 压到 0 之后直接 RenderFlex 溢出。
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kTagAreaMax),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final tag in diary.tags.take(2))
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 7),
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
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 标签退成同色系的纯文字：一行里塞两个描边小方框，视觉噪音比信息量大。
class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Text(
      '#$label',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: context.textTheme.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
      ),
    );
  }
}
