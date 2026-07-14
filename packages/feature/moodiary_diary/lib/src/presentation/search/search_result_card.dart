import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:substring_highlight/substring_highlight.dart';

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({
    super.key,
    required this.diary,
    required this.queryList,
    this.onTap,
  });

  final Diary diary;
  final List<String> queryList;

  /// 打开详情前的回调（如记录搜索历史）；之后照常 push 日记详情。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final textTheme = context.textTheme;
    final contentText = getHighlightedExcerpt(
      diary.contentText.trim().removeLineBreaks(),
      queryList,
    );
    final title = diary.title.removeLineBreaks();

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          onTap?.call();
          DiaryRoute(
            type: DiaryType.fromValue(diary.type).routeQuery,
            diaryId: diary.id,
          ).push(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotBlank) ...[
                SubstringHighlight(
                  text: title,
                  terms: queryList,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textStyle: textTheme.titleMedium!.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  textStyleHighlight: textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    backgroundColor: scheme.primaryContainer,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              SubstringHighlight(
                text: contentText,
                terms: queryList,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textStyle: textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textStyleHighlight: textTheme.bodyMedium!.copyWith(
                  height: 1.4,
                  backgroundColor: scheme.primaryContainer,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 13, color: scheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    TimeUtil.mediumDate(diary.time),
                    style: textTheme.bodySmall?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
