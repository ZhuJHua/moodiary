import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_diary/src/application/diary_stamp.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_card_parts.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class DiaryFeedTile extends StatelessWidget {
  final Diary diary;
  final DiarySort sort;
  final Place? place;
  final DiaryCardSyncState syncState;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  const DiaryFeedTile({
    super.key,
    required this.diary,
    this.sort = .timeDesc,
    this.place,
    this.syncState = .none,
    this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cells = DiaryMediaCell.forDiary(
      diary,
      pending: syncState == .syncing,
    );
    final hasMedia = cells.isNotEmpty;
    final title = diary.title.trim();
    final body = diary.contentText.preview();
    final typography = context.theme.typography;
    final textRows = <Widget>[
      if (title.isNotEmpty)
        Text(
          title,
          maxLines: 1,
          overflow: .ellipsis,
          style: typography.titleMedium.emphasized.onSurface,
        ),
      if (body.isNotEmpty)
        MediaMarkedText(
          body,
          maxLines: title.isNotEmpty ? 2 : (hasMedia ? 3 : 4),
          overflow: .ellipsis,
          style: title.isNotEmpty
              ? typography.bodyMedium.onSurfaceVariant
              : typography.bodyLarge.onSurface,
        ),
      DiaryCardMeta(
        diary: diary,
        stamp: TimeFormat.compactDateTime(diaryStampOf(diary, sort)),
        place: place,
        syncState: syncState,
        showMood: true,
      ),
    ];
    if (selecting && !hasMedia) {
      textRows[0] = Padding(
        padding: const .only(right: 26),
        child: textRows[0],
      );
    }

    return DiaryTileFrame(
      selecting: selecting,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      card: true,
      borderRadius: AppBorderRadius.largeBorderRadius,
      margin: const .symmetric(horizontal: 12),
      padding: .all(hasMedia ? 10 : 14),
      markInset: hasMedia ? 16 : 12,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (hasMedia) ...[
            _HeroMedia(cells: cells, aspect: diary.aspect),
            const SizedBox(height: 10),
          ],
          Padding(
            padding: hasMedia ? const .fromLTRB(4, 0, 4, 4) : .zero,
            child: Column(
              crossAxisAlignment: .start,
              spacing: 6,
              children: textRows,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMedia extends StatelessWidget {
  final List<DiaryMediaCell> cells;
  final double? aspect;

  const _HeroMedia({required this.cells, required this.aspect});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width <= 0) return const SizedBox.shrink();
      if (cells.length == 1) {
        // 竖图按 4:3 居中裁切，整宽方图会占掉大半屏
        final ratio = (cells.first.isVideo ? 1.6 : aspect ?? 1.6).clamp(
          4 / 3,
          2.0,
        );
        return SizedBox(
          width: width,
          height: width / ratio,
          child: cells.first,
        );
      }
      final mosaic = cells.length == 3;
      return ClipRRect(
        borderRadius: AppBorderRadius.mediumBorderRadius,
        child: SizedBox(
          height: width * (mosaic ? 0.54 : 0.55),
          child: Row(
            spacing: 3,
            crossAxisAlignment: .stretch,
            children: [
              Expanded(flex: mosaic ? 2 : 1, child: cells.first),
              Expanded(
                child: mosaic
                    ? Column(
                        spacing: 3,
                        crossAxisAlignment: .stretch,
                        children: [
                          Expanded(child: cells[1]),
                          Expanded(child: cells[2]),
                        ],
                      )
                    : cells[1],
              ),
            ],
          ),
        ),
      );
    },
  );
}
