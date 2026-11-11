/// Statistics and server metadata tools.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';

import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';
import 'arguments.dart';
import 'schemas.dart';

void registerStatsTools(
  McpRegistry registry, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
  required MoodInsightsRepository insights,
  required String appVersion,
}) {
  final stats = DiaryStatsOps(
    diaries: diaries,
    categories: categories,
    insights: insights,
  );

  registry.addTool(
    const McpTool(
      name: 'get_stats',
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
      inputSchema: {
        'type': 'object',
        'properties': {'months': statsMonthsSchema},
      },
      readOnly: true,
      idempotent: true,
    ),
    (call, arguments) async {
      final args = Args('get_stats', arguments);
      final months = args.optionalInt('months', fallback: 12, min: 1, max: 120);
      return McpToolResult.json(await stats.statsPayload(months: months));
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
