/// Statistics and server metadata tools.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';
import 'arguments.dart';
import 'diary_format.dart';

const int _defaultMonths = 12;

const int _maxMonths = 120;

void registerStatsTools(
  McpRegistry registry, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
  required MoodInsightsRepository insights,
  required String appVersion,
}) {
  registry.addTool(
    const McpTool(
      name: 'get_stats',
      title: 'Diary statistics',
      description:
          'Reports the diary count, the visible and recycle bin sizes, the '
          'diary count per local calendar month for the last months, the count '
          'per category, the mood distribution of visible diaries and the '
          'oldest diary time.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'months': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 120,
            'default': 12,
            'description':
                'How many calendar months the per-month counts cover, '
                'including the current month.',
          },
        },
      },
      readOnly: true,
      idempotent: true,
    ),
    (call, arguments) async {
      final args = Args('get_stats', arguments);
      final months = args.optionalInt(
        'months',
        fallback: _defaultMonths,
        min: 1,
        max: _maxMonths,
      );
      return McpToolResult.json(
        await statsOverview(
          diaries: diaries,
          categories: categories,
          insights: insights,
          months: months,
        ),
      );
    },
  );

  registry.addTool(
    const McpTool(
      name: 'server_info',
      title: 'Moodiary server info',
      description:
          'Reports the Moodiary version, the diary count and the categories '
          'this MCP server is connected to.',
      inputSchema: {'type': 'object', 'properties': {}},
      readOnly: true,
      idempotent: true,
    ),
    (call, arguments) async {
      final total = await diaries.countAllDiaries();
      final categories_ = await categories.getAllCategories();
      return McpToolResult.json({
        'server': mcpServerName,
        'version': appVersion,
        'protocolVersions': mcpSupportedProtocolVersions,
        'diaries': total,
        'categories': categories_.length,
      });
    },
  );
}

/// The `get_stats` payload, also served as `moodiary://stats/overview`.
Future<Map<String, dynamic>> statsOverview({
  required DiaryRepository diaries,
  required CategoryRepository categories,
  required MoodInsightsRepository insights,
  int months = _defaultMonths,
}) async {
  final total = await diaries.countAllDiaries();
  final byCategory = await diaries.diaryCountByCategory();
  final categoryList = await categories.getAllCategories();
  final names = {
    for (final category in categoryList) category.id: category.categoryName,
  };
  final monthly = await diaries.diaryCountByMonth(sort: DiarySort.timeDesc);
  final earliest = await insights.earliestEntry();

  final now = DateTime.now();
  final monthRows = <Map<String, dynamic>>[];
  for (var back = months - 1; back >= 0; back--) {
    final key = DateTime(now.year, now.month - back);
    monthRows.add({'month': _monthKey(key), 'diaries': monthly[key] ?? 0});
  }

  final entries = await visibleDiaryEntries(insights);
  final mood = summarizeMood(entries);
  final recorded = mood.distribution.values.fold(0, (sum, n) => sum + n);
  final categorised = byCategory.byCategory.values.fold(0, (sum, n) => sum + n);

  final categoryRows = <Map<String, dynamic>>[
    for (final entry in byCategory.byCategory.entries)
      {
        'categoryId': entry.key,
        'categoryName': names[entry.key],
        'diaries': entry.value,
      },
  ]..sort((a, b) => (b['diaries']! as int).compareTo(a['diaries']! as int));

  return {
    'totalDiaries': total,
    'visibleDiaries': byCategory.total,
    // The recycle bin is exactly the hidden rows, so no second query is needed.
    'recycleBinDiaries': total - byCategory.total,
    'uncategorizedDiaries': byCategory.total - categorised,
    'firstDiaryTime': earliest == null ? null : isoUtc(earliest),
    'months': monthRows,
    'categories': categoryRows,
    'moods': {
      'distribution': {
        for (final level in DiaryMood.values)
          level.name: mood.distribution[level] ?? 0,
      },
      'recordedDiaries': recorded,
      'diariesWithoutMood': byCategory.total - recorded,
      'averageScore': mood.average,
      'recordedDays': mood.recordedDays,
    },
    'generatedAt': isoUtc(DateTime.now()),
  };
}

/// Every visible diary as the light projection the mood insights read model
/// uses. Prompt completions need days and titles without loading diary bodies.
Future<List<MoodInsightEntry>> visibleDiaryEntries(
  MoodInsightsRepository insights,
) async {
  final earliest = await insights.earliestEntry();
  if (earliest == null) return const [];
  return insights.entries(
    earliest,
    DateTime.now().add(const Duration(days: 1)),
  );
}

String _monthKey(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';
