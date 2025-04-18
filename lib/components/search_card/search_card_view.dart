import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/border.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/pages/diary_details/diary_details_logic.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:substring_highlight/substring_highlight.dart';

String getHighlightedExcerpt(
  String content,
  List<String> keywords, {
  int contextLength = 50,
}) {
  for (final word in keywords) {
    final index = content.indexOf(word);
    if (index != -1) {
      final wordStart = index;
      final wordEnd = index + word.length;

      int start = wordStart - contextLength;
      int end = wordEnd + contextLength;

      if (start < 0) {
        end += -start;
        start = 0;
      }
      if (end > content.length) {
        final overflow = end - content.length;
        start = (start - overflow).clamp(0, content.length);
        end = content.length;
      }

      final snippet = content.substring(start, end);

      final hasHead = start > 0;
      final hasTail = end < content.length;

      return "${hasHead ? '...' : ''}$snippet${hasTail ? '...' : ''}";
    }
  }

  // 没有关键词命中，返回默认摘要
  final fallback = content.length > 200 ? content.substring(0, 200) : content;
  return "${fallback.trimRight()}${content.length > 200 ? '...' : ''}";
}

class SearchCardComponent extends StatelessWidget {
  const SearchCardComponent({
    super.key,
    required this.diary,
    required this.queryList,
  });

  final List<String> queryList;

  final Diary diary;

  @override
  Widget build(BuildContext context) {
    final contentText = getHighlightedExcerpt(
      diary.contentText.removeLineBreaks(),
      queryList,
    );
    final title = diary.title.removeLineBreaks();
    return InkWell(
      onTap: () async {
        Bind.lazyPut(() => DiaryDetailsLogic(), tag: diary.id);
        await Get.toNamed(
          AppRoutes.diaryPage,
          arguments: [diary.clone(), false],
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppBorderRadius.smallBorderRadius,
        ),
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4.0,
                children: [
                  if (title.isNotBlank)
                    SubstringHighlight(
                      text: title,
                      terms: queryList,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textStyle: context.textTheme.titleMedium!.copyWith(
                        color: context.theme.colorScheme.onSurface,
                      ),
                      textStyleHighlight: context.textTheme.titleMedium!
                          .copyWith(
                            backgroundColor: context.theme.colorScheme.primary,
                            color: context.theme.colorScheme.onPrimary,
                          ),
                    ),
                  SubstringHighlight(
                    text: contentText,
                    terms: queryList,
                    textStyle: context.textTheme.bodyMedium!.copyWith(
                      color: context.theme.colorScheme.onSurface,
                    ),
                    textStyleHighlight: context.textTheme.bodyMedium!.copyWith(
                      backgroundColor: context.theme.colorScheme.primary,
                      color: context.theme.colorScheme.onPrimary,
                    ),
                  ),
                  Text(diary.time.toString().split('.')[0]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
