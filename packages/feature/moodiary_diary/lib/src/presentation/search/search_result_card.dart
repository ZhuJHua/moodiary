import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class SearchResultCard extends ConsumerWidget {
  const SearchResultCard({
    super.key,
    required this.hit,
    this.query = '',
    this.tagName,
    this.onTap,
  });

  final DiarySearchHit hit;
  final String query;
  final String? tagName;

  final VoidCallback? onTap;

  static List<InlineSpan> _hits(
    String marked,
    TextStyle base,
    TextStyle highlight,
  ) => [
    for (final (text, isHit) in splitSearchHighlight(marked))
      TextSpan(text: text, style: isHit ? highlight : base),
  ];

  static TextSpan _spans(String marked, TextStyle base, TextStyle highlight) =>
      TextSpan(children: _hits(marked, base, highlight));

  static TextSpan _excerptSpans(
    String marked,
    TextStyle base,
    TextStyle highlight,
  ) => TextSpan(
    children: mediaMarkedSpans(
      marked,
      style: base,
      textSpans: (text) => _hits(text, base, highlight),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final scheme = theme.colors;
    final typography = theme.typography;
    final diary = hit.diary;
    final tags = resolveTagNames(
      diary.tagIds,
      ref.watch(tagCatalogProvider).value?.byId ?? const {},
    );
    final keyword = query.trim().toLowerCase();
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
                _excerptSpans(
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
              if (tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final tag in tags)
                      Text(
                        '#${tag.name}',
                        style:
                            tag.name == tagName ||
                                (keyword.isNotEmpty &&
                                    tag.name.toLowerCase().contains(keyword))
                            ? typography.labelSmall.onPrimaryContainer.copyWith(
                                backgroundColor: scheme.primaryContainer,
                              )
                            : typography.labelSmall.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
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
