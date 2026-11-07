/// Resources of the diary catalog: the category tree, the newest diaries, the
/// statistics payload and one diary per URI.
library;

import 'package:moodiary_data/moodiary_data.dart';

import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';
import '../tools/category_tools.dart';
import '../tools/diary_format.dart';
import '../tools/diary_tools.dart';
import '../tools/stats_tools.dart';

/// How many diaries `moodiary://diaries/recent` holds. The service sends a
/// `notifications/resources/updated` for this URI on every diary change.
const int _recentDiaryCount = 20;

void registerDiaryResources(
  McpRegistry registry, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
  required MoodInsightsRepository insights,
}) {
  registry.addResource(
    const McpResource(
      uri: 'moodiary://categories',
      name: 'categories',
      title: 'Diary categories',
      description:
          'Every diary category as a tree, with its parent, ARGB colour and '
          "the number of visible diaries in it.",
      mimeType: 'application/json',
    ),
    (call, uri) async => McpResourceReadResult.json(
      uri,
      await categoryTreePayload(categories, diaries),
    ),
  );

  registry.addResource(
    const McpResource(
      uri: 'moodiary://diaries/recent',
      name: 'recent-diaries',
      title: 'Recent diaries',
      description:
          'The $_recentDiaryCount newest visible diaries as summaries (id, '
          'title, time, category, mood, tags, excerpt). Read '
          'moodiary://diary/{id} for a body.',
      mimeType: 'application/json',
    ),
    (call, uri) async {
      final page = await diaryPage(diaries, limit: _recentDiaryCount);
      final names = await categoryNames(categories);
      return McpResourceReadResult.json(uri, {
        'diaries': [
          for (final diary in page)
            diarySummary(diary, categoryName: names[diary.categoryId]),
        ],
        'count': page.length,
        'generatedAt': isoUtc(DateTime.now()),
      });
    },
  );

  registry.addResource(
    const McpResource(
      uri: 'moodiary://stats/overview',
      name: 'stats-overview',
      title: 'Diary statistics',
      description:
          'The get_stats payload: diary counts, per-month counts for the last '
          '12 months, per-category counts and the mood distribution.',
      mimeType: 'application/json',
    ),
    (call, uri) async => McpResourceReadResult.json(
      uri,
      await statsOverview(
        diaries: diaries,
        categories: categories,
        insights: insights,
      ),
    ),
  );

  registry.addResourceTemplate(
    const McpResourceTemplate(
      uriTemplate: '$diaryUriPrefix{id}',
      name: 'diary',
      title: 'One diary',
      description:
          'One diary as Markdown behind a JSON front matter block (id, title, '
          'time, category, mood, tags, links). Unknown ids are a resource '
          'not found error.',
      mimeType: 'text/markdown',
    ),
    (call, uri, variables) async {
      final id = variables['id'] ?? '';
      final diary = await diaries.getDiaryByBusinessId(id);
      if (diary == null) {
        throw JsonRpcException(
          JsonRpcCode.resourceNotFound,
          'no diary with id="$id"',
        );
      }
      final names = await categoryNames(categories);
      return McpResourceReadResult.text(
        uri,
        diaryMarkdownDocument(
          diary,
          categoryName: names[diary.categoryId],
          links: await diaryLinkSummary(diaries, diary),
        ),
        mimeType: 'text/markdown',
      );
    },
  );
}
