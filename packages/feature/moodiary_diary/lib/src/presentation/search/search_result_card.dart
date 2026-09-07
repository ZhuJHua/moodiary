import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';
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

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scheme = theme.colors;
    final typography = theme.typography;
    final contentText = getHighlightedExcerpt(
      diary.contentText.trim().removeLineBreaks(),
      queryList,
    );
    final title = diary.title.removeLineBreaks();

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: .circular(16),
      clipBehavior: .antiAlias,
      child: MInkWell(
        onTap: () {
          onTap?.call();
          DiaryRoute(diaryId: diary.id).push(context);
        },
        child: Padding(
          padding: const .all(14),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              if (title.trim().isNotEmpty) ...[
                SubstringHighlight(
                  text: title,
                  terms: queryList,
                  maxLines: 1,
                  overflow: .ellipsis,
                  textStyle: typography.titleMedium.emphasized.onSurface,
                  textStyleHighlight: typography
                      .titleMedium
                      .emphasized
                      .onPrimaryContainer
                      .copyWith(backgroundColor: scheme.primaryContainer),
                ),
                const SizedBox(height: 6),
              ],
              SubstringHighlight(
                text: contentText,
                terms: queryList,
                maxLines: 3,
                overflow: .ellipsis,
                textStyle: typography.bodyMedium.onSurfaceVariant.copyWith(
                  height: 1.4,
                ),
                textStyleHighlight: typography.bodyMedium.onPrimaryContainer
                    .copyWith(
                      height: 1.4,
                      backgroundColor: scheme.primaryContainer,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(LucideIcons.clock, size: 13, color: scheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    TimeFormat.mediumDate(diary.time),
                    style: typography.bodySmall.outline,
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
