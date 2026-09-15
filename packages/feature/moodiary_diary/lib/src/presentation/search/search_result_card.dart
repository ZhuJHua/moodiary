import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({super.key, required this.hit, this.onTap});

  final DiarySearchHit hit;

  final VoidCallback? onTap;

  static TextSpan _spans(String marked, TextStyle base, TextStyle highlight) =>
      TextSpan(
        children: [
          for (final (text, isHit) in splitSearchHighlight(marked))
            TextSpan(text: text, style: isHit ? highlight : base),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scheme = theme.colors;
    final typography = theme.typography;
    final diary = hit.diary;
    final title = hit.titleHighlight.removeLineBreaks();
    final excerpt = hit.excerpt.removeLineBreaks();

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
                Text.rich(
                  _spans(
                    title,
                    typography.titleMedium.emphasized.onSurface,
                    typography.titleMedium.emphasized.onPrimaryContainer
                        .copyWith(backgroundColor: scheme.primaryContainer),
                  ),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
                const SizedBox(height: 6),
              ],
              Text.rich(
                _spans(
                  excerpt,
                  typography.bodyMedium.onSurfaceVariant.copyWith(height: 1.4),
                  typography.bodyMedium.onPrimaryContainer.copyWith(
                    height: 1.4,
                    backgroundColor: scheme.primaryContainer,
                  ),
                ),
                maxLines: 3,
                overflow: .ellipsis,
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
