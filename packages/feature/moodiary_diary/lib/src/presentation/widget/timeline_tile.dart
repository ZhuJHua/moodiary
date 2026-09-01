import 'dart:io';

import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

/// 左栏三段固定宽度：日期列 / 间隙 / 轴列 / 间隙。轴心 x 与内容起始 x 都由它们推出，
/// Painter 与 Row 必须用同一组常量，否则线会画歪。
const double _kDateWidth = 30.0;
const double _kAxisWidth = 20.0;
const double _kGap = 8.0;
const double _kAxisCenter = _kDateWidth + _kGap + _kAxisWidth / 2;

/// 断档时上方多留的空白 —— 让「隔了几天」在版面上真的有间隔感。
const double _kBreakPad = 14.0;
const double _kTopPad = 4.0;
const double _kBottomPad = 14.0;

/// 圆点相对本行内容顶部的中心偏移：与元信息行（11px 字 + 12px 图标）的视觉中线对齐。
const double _kDotOffset = 9.0;

/// 时间线最多展示三张图，多出来的折成末张上的「+N」。
const int _kMaxImages = 3;

/// 时间线的一行 = 一篇日记。左栏日期只在当天第一条出现，轴上圆点每条都有 ——
/// 一天多篇时不会共用一个心情色。
class DiaryTimelineTile extends StatelessWidget {
  final Diary diary;

  /// 参与分组的时间戳（本地）。按「最近修改」排序时它是 lastModified。
  final DateTime stamp;
  final bool dayStart;
  final bool breakBefore;

  /// 下一条与本条之间也隔了整天 —— 本条圆点**以下**那段同样属于空档，一并画成虚线。
  /// 只虚上面一小截的话，两颗圆点之间绝大部分仍是实线，看不出「这里空了几天」。
  final bool breakAfter;

  /// 上面还有没有条目：列表首条不画上半段轴。
  final bool hasAbove;

  /// 下一条的心情值 —— 圆点以下那段由本条的颜色渐变到它；null 表示列表末条。
  final DiaryMood? moodBelow;

  final Category? category;
  final bool showCategoryLabel;
  final DiaryCardSyncState syncState;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  const DiaryTimelineTile({
    super.key,
    required this.diary,
    required this.stamp,
    required this.dayStart,
    required this.breakBefore,
    this.breakAfter = false,
    this.hasAbove = false,
    this.moodBelow,
    this.category,
    this.showCategoryLabel = true,
    this.syncState = .none,
    this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final topPad = _kTopPad + (breakBefore ? _kBreakPad : 0.0);
    final mood = diaryMoodColor(diary.mood);

    return CustomPaint(
      painter: _AxisPainter(
        color: mood,
        hasAbove: hasAbove,
        below: moodBelow == null ? null : diaryMoodColor(moodBelow!),
        dashedAbove: breakBefore,
        dashedBelow: breakAfter,
        idle: colors.outlineVariant,
        dotDy: topPad + _kDotOffset,
        big: dayStart,
      ),
      // 点击响应放在内容块里（见 [_Content]），不包整行：整行 InkWell 的水波是个直角
      // 矩形，会从日期列和轴线上直接洗过去，把轴那条线糊掉。
      child: Padding(
        padding: .only(top: topPad, bottom: _kBottomPad),
        child: Row(
          crossAxisAlignment: .start,
          children: [
            SizedBox(
              width: _kDateWidth,
              child: dayStart ? _DateColumn(stamp: stamp) : null,
            ),
            const SizedBox(width: _kGap + _kAxisWidth + _kGap),
            Expanded(
              child: _Content(
                diary: diary,
                stamp: stamp,
                category: category,
                showCategoryLabel: showCategoryLabel,
                syncState: syncState,
                selecting: selecting,
                selected: selected,
                onTap: onTap,
                onLongPress: onLongPress,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateColumn extends StatelessWidget {
  final DateTime stamp;

  const _DateColumn({required this.stamp});

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography;
    return Column(
      crossAxisAlignment: .end,
      children: [
        Text(
          '${stamp.day}',
          style: typo.titleMedium.emphasized.onSurface.copyWith(
            height: 1.05,
            fontFeatures: const [.tabularFigures()],
          ),
        ),
        Text(
          TimeFormat.weekdayShort(stamp),
          maxLines: 1,
          overflow: .clip,
          style: typo.labelSmall.onSurfaceVariant.copyWith(height: 1.1),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  final Diary diary;
  final DateTime stamp;
  final Category? category;
  final bool showCategoryLabel;
  final DiaryCardSyncState syncState;
  final bool selecting;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _Content({
    required this.diary,
    required this.stamp,
    required this.category,
    required this.showCategoryLabel,
    required this.syncState,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography;
    final hasTitle = diary.title.trim().isNotEmpty;
    final body = diary.contentText.preview();

    return DiaryTileFrame(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          _MetaLine(
            diary: diary,
            stamp: stamp,
            category: category,
            showCategoryLabel: showCategoryLabel,
            syncState: syncState,
            selecting: selecting,
            selected: selected,
          ),
          if (hasTitle) ...[
            const SizedBox(height: 3),
            Text(
              diary.title.trim(),
              maxLines: 1,
              overflow: .ellipsis,
              style: typo.titleMedium.onSurface,
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              body,
              maxLines: hasTitle ? 2 : 3,
              overflow: .ellipsis,
              style: typo.bodyMedium.onSurfaceVariant,
            ),
          ],
          if (diary.imageName.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Images(names: diary.imageName, aspect: diary.aspect),
          ],
          _Footer(diary: diary),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final Diary diary;
  final DateTime stamp;
  final Category? category;
  final bool showCategoryLabel;
  final DiaryCardSyncState syncState;
  final bool selecting;
  final bool selected;

  const _MetaLine({
    required this.diary,
    required this.stamp,
    required this.category,
    required this.showCategoryLabel,
    required this.syncState,
    required this.selecting,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final onVariant = colors.onSurfaceVariant;
    final style = context.theme.typography.labelSmall.onSurfaceVariant;
    final weather = diary.weather;

    return Row(
      children: [
        // 左半组整体 Expanded、天气在组内 Flexible：不能写成「Flexible(天气) + Spacer()」——
        // 两个 flex 子节点会均分剩余宽度，Spacer 拿到的那一半空着也不让，天气会在旁边
        // 留着等宽空白的情况下先打省略号。
        Expanded(
          child: Row(
            children: [
              Text(TimeFormat.clock(stamp), style: style),
              if (weather != null) ...[
                const SizedBox(width: 8),
                Icon(
                  // 天气来自和风，图标跟着数据源走；未知码退回通用的云。
                  qweatherIcon(weather.icon) ?? LucideIcons.cloud,
                  size: 12,
                  color: onVariant,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '${weather.text} ${weather.temp}°',
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: style,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (syncState != .none) ...[
          DiarySyncBadge(state: syncState),
          const SizedBox(width: 8),
        ],
        if (selecting)
          DiarySelectMark(selected: selected)
        else if (showCategoryLabel && category != null)
          _CategoryLabel(category: category!, style: style),
      ],
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  final Category category;
  final TextStyle? style;

  const _CategoryLabel({required this.category, required this.style});

  @override
  Widget build(BuildContext context) {
    final color = categoryColorOf(colorValue: category.color, id: category.id);
    return Row(
      mainAxisSize: .min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: .circle),
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 84),
          child: Text(
            category.categoryName,
            maxLines: 1,
            overflow: .ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// 图片区：最多三张，按张数换尺寸——1 张给整幅大图，2/3 张等分方格，
/// 超出的折进末张的「+N」。
class _Images extends StatelessWidget {
  final List<String> names;
  final double? aspect;

  const _Images({required this.names, required this.aspect});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final show = names.length > _kMaxImages ? _kMaxImages : names.length;
    final extra = names.length - show;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width <= 0) return const SizedBox.shrink();

        if (show == 1) {
          // aspect 目前全仓没有写入方，取不到就按 16:10 裁切；等主色/比例管线补上后
          // 竖图会自动收窄而不是被裁掉大半。
          final ratio = (aspect ?? 16 / 10).clamp(0.6, 2.0).toDouble();
          final boxWidth = ratio < 1 ? width * 0.58 : width;
          return SizedBox(
            width: boxWidth,
            height: boxWidth / ratio,
            child: _Thumb(
              name: names.first,
              cacheWidth: (boxWidth * dpr).round(),
              radius: AppBorderRadius.mediumBorderRadius,
            ),
          );
        }

        const gap = 4.0;
        final cell = (width - gap * (show - 1)) / show;
        return Row(
          children: [
            for (var i = 0; i < show; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: cell,
                height: cell,
                child: _Thumb(
                  name: names[i],
                  cacheWidth: (cell * dpr).round(),
                  radius: AppBorderRadius.smallBorderRadius,
                  moreCount: i == show - 1 && extra > 0 ? extra : 0,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  final String name;
  final int cacheWidth;
  final BorderRadius radius;
  final int moreCount;

  const _Thumb({
    required this.name,
    required this.cacheWidth,
    required this.radius,
    this.moreCount = 0,
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
            // 按文件名 key：开了 gaplessPlayback，换图期间旧帧不会清空，列表重排后
            // 复用同一个 Element 会先画上一篇日记的照片。与媒体库同一处理。
            key: ValueKey(name),
            image: ResizeImage(
              FileImage(File(AppFiles.getRealPath('image', name))),
              width: cacheWidth,
            ),
            fit: .cover,
            gaplessPlayback: true,
            // 重装后媒体文件会被清空而日记还在——没有 errorBuilder 就是一片空白。
            errorBuilder: (context, _, _) =>
                Icon(LucideIcons.imageOff, color: colors.onSurfaceVariant),
          ),
          if (moreCount > 0)
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.scrim.withValues(alpha: 0.45),
              ),
              child: Center(
                child: Text(
                  '+$moreCount',
                  style:
                      context.theme.typography.titleMedium.emphasized.onMedia,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 语音 / 视频 / 标签 / 地点：一行细元信息，都没有就整行不占高。
class _Footer extends StatelessWidget {
  final Diary diary;

  const _Footer({required this.diary});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final style = context.theme.typography.labelSmall.onSurfaceVariant;
    final chips = <Widget>[];

    if (diary.audioName.isNotEmpty) {
      chips.add(
        _MediaChip(
          icon: LucideIcons.mic,
          count: diary.audioName.length,
          style: style,
        ),
      );
    }
    if (diary.videoName.isNotEmpty) {
      chips.add(
        _MediaChip(
          icon: LucideIcons.video,
          count: diary.videoName.length,
          style: style,
        ),
      );
    }
    for (final tag in diary.tags.take(2)) {
      chips.add(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 108),
          child: Text('#$tag', maxLines: 1, overflow: .ellipsis, style: style),
        ),
      );
    }
    if (diary.tags.length > 2) {
      chips.add(Text('+${diary.tags.length - 2}', style: style));
    }
    final place = diary.position?.name.trim() ?? '';
    if (place.isNotEmpty) {
      chips.add(
        Row(
          mainAxisSize: .min,
          children: [
            Icon(LucideIcons.mapPin, size: 12, color: colors.onSurfaceVariant),
            const SizedBox(width: 2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Text(
                place,
                maxLines: 1,
                overflow: .ellipsis,
                style: style,
              ),
            ),
          ],
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const .only(top: 6),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: .center,
        children: chips,
      ),
    );
  }
}

/// 时长没有存在模型里（[Diary] 只有文件名），所以这里只表达「有几段」，
/// 不假装知道播放时长。
class _MediaChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final TextStyle? style;

  const _MediaChip({
    required this.icon,
    required this.count,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      children: [
        Icon(icon, size: 13, color: context.theme.colors.onSurfaceVariant),
        if (count > 1) ...[
          const SizedBox(width: 2),
          Text('$count', style: style),
        ],
      ],
    );
  }
}

/// 轴：上下两段渐变 + 一颗心情色圆点。断档整段画成虚线并取中性色 —— 那里没有情绪可言。
class _AxisPainter extends CustomPainter {
  final Color color;

  /// 上面还有没有条目 —— 只决定要不要画上半段，颜色一律用本条自己的。
  final bool hasAbove;
  final Color? below;
  final bool dashedAbove;
  final bool dashedBelow;
  final Color idle;
  final double dotDy;
  final bool big;

  const _AxisPainter({
    required this.color,
    required this.hasAbove,
    required this.below,
    required this.dashedAbove,
    required this.dashedBelow,
    required this.idle,
    required this.dotDy,
    required this.big,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const x = _kAxisCenter;
    final radius = big ? 5.0 : 3.5;
    final clear = radius + 3.0;

    // 两颗圆点之间的整段过渡都放在**圆点以下**那一段完成：圆点贴着行顶（dotDy 只有
    // 13px），上一段留给它的高度不到 7px，把整幅色差塞进去会变成一次硬切换。
    // 圆点以上因此是本条自己的纯色 —— 上一行底边画到的正是本条的颜色，接缝严丝合缝。
    if (hasAbove) {
      final top = dotDy - clear;
      if (top > 0) {
        if (dashedAbove) {
          _dash(canvas, x, 0, top, idle);
        } else {
          _segment(canvas, x, 0, top, color, color);
        }
      }
    }
    if (below != null) {
      final bottom = dotDy + clear;
      if (size.height > bottom) {
        if (dashedBelow) {
          _dash(canvas, x, bottom, size.height, idle);
        } else {
          _segment(canvas, x, bottom, size.height, color, below!);
        }
      }
    }

    canvas.drawCircle(Offset(x, dotDy), radius, Paint()..color = color);
  }

  void _segment(
    Canvas canvas,
    double x,
    double y0,
    double y1,
    Color a,
    Color b,
  ) {
    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = .round
      ..shader = LinearGradient(
        begin: .topCenter,
        end: .bottomCenter,
        colors: [a, b],
      ).createShader(.fromLTRB(x - 1, y0, x + 1, y1));
    canvas.drawLine(Offset(x, y0), Offset(x, y1), paint);
  }

  void _dash(Canvas canvas, double x, double y0, double y1, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = .round;
    const dash = 3.0, gap = 4.0;
    for (var y = y0; y < y1; y += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + dash).clamp(y0, y1)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AxisPainter old) =>
      old.color != color ||
      old.hasAbove != hasAbove ||
      old.below != below ||
      old.dashedAbove != dashedAbove ||
      old.dashedBelow != dashedBelow ||
      old.idle != idle ||
      old.dotDy != dotDy ||
      old.big != big;
}
