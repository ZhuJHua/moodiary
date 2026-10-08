import 'package:fast_image/fast_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

class DiaryEntryTile extends ConsumerWidget {
  final Diary diary;
  final bool showDate;

  const DiaryEntryTile({super.key, required this.diary, this.showDate = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final colors = theme.colors;
    final category = ref.watch(categoryByIdProvider(diary.categoryId));
    final cover = diary.imageName.firstOrNull;
    final title = diary.title.trim().isEmpty
        ? context.l10n.common.untitled
        : diary.title;

    return Padding(
      padding: const .only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: .circular(14),
        ),
        child: MInkWell(
          borderRadius: .circular(14),
          onTap: () => DiaryRoute(diaryId: diary.id).push(context),
          child: Padding(
            padding: const .all(10),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                if (cover != null) ...[
                  ClipRRect(
                    borderRadius: .circular(9),
                    child: Image(
                      image: FastImage(
                        AppFiles.getRealPath('image', cover),
                        tier: .s,
                        decodeWidth:
                            (44 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                      ),
                      width: 44,
                      height: 44,
                      fit: .cover,
                      errorBuilder: (context, _, _) => SizedBox.square(
                        dimension: 44,
                        child: ColoredBox(color: colors.surfaceContainerHigh),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: theme.typography.bodyMedium.emphasized.onSurface,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (category != null) ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: .circle,
                                color: categoryColorOf(
                                  colorValue: category.color,
                                  id: category.id,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              category.categoryName,
                              style:
                                  theme.typography.labelSmall.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            showDate
                                ? TimeFormat.compactDateTime(diary.time)
                                : TimeFormat.clock(diary.time),
                            style: theme.typography.labelSmall.outline,
                          ),
                        ],
                      ),
                      if (diary.contentText.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          diary.contentText.trim(),
                          maxLines: 2,
                          overflow: .ellipsis,
                          style: theme.typography.bodySmall.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
