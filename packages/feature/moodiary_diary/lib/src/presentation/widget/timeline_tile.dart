import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_card_parts.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

const double _kDateWidth = 30.0;
const double _kAxisWidth = 20.0;
const double _kGap = 8.0;
const double _kAxisCenter = _kDateWidth + _kGap + _kAxisWidth / 2;

const double _kBreakPad = 14.0;
const double _kTopPad = 4.0;
const double _kBottomPad = 14.0;
// 选中底色要包住文字：内容上下各留一点，日期列和圆点一起下移
const double _kFramePadV = 6.0;

class DiaryTimelineTile extends StatelessWidget {
  final Diary diary;

  final DateTime stamp;
  final bool dayStart;
  final bool breakBefore;

  final bool breakAfter;

  final bool hasAbove;

  final DiaryMood? moodBelow;
  final bool hasBelow;

  final Place? place;
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
    this.hasBelow = false,
    this.place,
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
    final mood = diary.mood?.colorOf(context) ?? colors.outlineVariant;
    final typography = context.theme.typography;
    final title = diary.title.trim();
    final body = diary.contentText.preview();
    final bodyStyle = title.isEmpty
        ? typography.bodyMedium.onSurface
        : typography.bodyMedium.onSurfaceVariant;
    final titleStyle = typography.titleMedium.emphasized.onSurface;
    final cells = DiaryMediaCell.forDiary(
      diary,
      pending: syncState == .syncing,
    );
    final firstLineStyle = title.isNotEmpty
        ? titleStyle
        : body.isNotEmpty
        ? bodyStyle
        : typography.labelSmall.onSurfaceVariant;
    final mediaFirst = title.isEmpty && body.isEmpty && cells.isNotEmpty;
    final textRows = <Widget>[
      if (title.isNotEmpty)
        Text(title, maxLines: 1, overflow: .ellipsis, style: titleStyle),
      if (body.isNotEmpty)
        MediaMarkedText(
          body,
          maxLines: title.isNotEmpty ? 2 : 3,
          overflow: .ellipsis,
          style: bodyStyle,
        ),
      if (cells.isNotEmpty) _TimelineMedia(cells: cells, aspect: diary.aspect),
      DiaryCardMeta(
        diary: diary,
        stamp: TimeFormat.clock(stamp),
        place: place,
        syncState: syncState,
      ),
    ];
    if (selecting) {
      final index = mediaFirst ? 1 : 0;
      textRows[index] = Padding(
        padding: const .only(right: 26),
        child: textRows[index],
      );
    }

    return CustomPaint(
      painter: _AxisPainter(
        color: mood,
        hollow: diary.mood == null,
        outline: colors.outline,
        hasAbove: hasAbove,
        below: hasBelow || moodBelow != null
            ? moodBelow?.colorOf(context) ?? colors.outlineVariant
            : null,
        dashedAbove: breakBefore,
        dashedBelow: breakAfter,
        idle: colors.outlineVariant,
        dotDy:
            topPad +
            _kFramePadV +
            (mediaFirst
                ? 12
                : diaryScaledLineHeight(context, firstLineStyle) / 2),
        big: dayStart,
      ),
      child: Padding(
        padding: .only(top: topPad, bottom: _kBottomPad),
        child: Row(
          crossAxisAlignment: .start,
          children: [
            SizedBox(
              width: _kDateWidth,
              child: dayStart
                  ? Padding(
                      padding: const .only(top: _kFramePadV),
                      child: _DateColumn(stamp: stamp),
                    )
                  : null,
            ),
            const SizedBox(width: _kGap + _kAxisWidth + _kGap),
            Expanded(
              child: DiaryTileFrame(
                padding: const .fromLTRB(10, _kFramePadV, 10, _kFramePadV),
                selecting: selecting,
                selected: selected,
                onTap: onTap,
                onLongPress: onLongPress,
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 6,
                  children: textRows,
                ),
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

class _TimelineMedia extends StatelessWidget {
  final List<DiaryMediaCell> cells;
  final double? aspect;

  const _TimelineMedia({required this.cells, required this.aspect});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width <= 0) return const SizedBox.shrink();
      if (cells.length == 1) {
        final ratio = cells.first.isVideo ? 1.6 : aspect ?? 1.6;
        final portrait = ratio < 1;
        final cellWidth = portrait ? width * 0.5 : width;
        final cellRatio = portrait
            ? ratio.clamp(0.75, 1.0)
            : ratio.clamp(1.6, 2.2);
        return SizedBox(
          width: cellWidth,
          height: cellWidth / cellRatio,
          child: cells.first,
        );
      }
      const gap = 4.0;
      final size = (width - gap * 2) / 3;
      if (size <= 0) return const SizedBox.shrink();
      return Row(
        spacing: gap,
        children: [
          for (final cell in cells)
            SizedBox.square(dimension: size, child: cell),
        ],
      );
    },
  );
}

class _AxisPainter extends CustomPainter {
  final Color color;
  final bool hollow;
  final Color outline;

  final bool hasAbove;
  final Color? below;
  final bool dashedAbove;
  final bool dashedBelow;
  final Color idle;
  final double dotDy;
  final bool big;

  const _AxisPainter({
    required this.color,
    required this.hollow,
    required this.outline,
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
    // 圆头线帽会探出条目底边半个线宽；月份分组是倒序绘制的，
    // 上个月最后一条的线帽会盖到下个月吸顶头上，看起来像一道缝
    canvas.clipRect(Offset.zero & size);
    const x = _kAxisCenter;
    final radius = big ? 5.0 : 3.5;
    final clear = radius + 3.0;

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

    canvas.drawCircle(
      Offset(x, dotDy),
      radius,
      Paint()
        ..color = hollow ? outline : color
        ..style = hollow ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 1.5,
    );
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
      old.hollow != hollow ||
      old.outline != outline ||
      old.hasAbove != hasAbove ||
      old.below != below ||
      old.dashedAbove != dashedAbove ||
      old.dashedBelow != dashedBelow ||
      old.idle != idle ||
      old.dotDy != dotDy ||
      old.big != big;
}
