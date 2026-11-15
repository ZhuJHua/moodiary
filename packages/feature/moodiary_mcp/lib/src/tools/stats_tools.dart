/// Diary statistics tools.
library;

import 'package:mcp_dart/mcp_dart.dart';
import 'package:moodiary_data/moodiary_data.dart';

import 'arguments.dart';
import 'mcp_results.dart';
import 'schemas.dart';
import 'stats_payloads.dart';

void registerStatsTools(
  McpServer server, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
  required MoodInsightsRepository insights,
}) {
  final stats = McpStatsPayloads(
    diaries: diaries,
    categories: categories,
    insights: insights,
  );

  server.registerTool(
    'get_stats',
    title: 'Diary statistics',
    description:
        'Reports the diary totals (all rows, visible, recycle bin, '
        'uncategorized), the diary count per local calendar month for the '
        'last months, the count per category, the mood distribution of '
        'visible diaries and the oldest diary time. monthsWindow names the '
        'months the bucket list covers; olderDiaries and futureDiaries count '
        'the visible diaries outside that window, so '
        'sum(months.diaries) + olderDiaries + futureDiaries == '
        'visibleDiaries always holds and no diary is missing from the sum.',
    inputSchema: const ToolArgumentSchema({
      'type': 'object',
      'properties': {'months': statsMonthsSchema},
    }),
    annotations: const ToolAnnotations(
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    ),
    callback: (arguments, call) async {
      final args = Args('get_stats', arguments);
      final months = args.optionalInt('months', fallback: 12, min: 1, max: 120);
      return jsonToolResult(await stats.statsPayload(months: months));
    },
  );
}
