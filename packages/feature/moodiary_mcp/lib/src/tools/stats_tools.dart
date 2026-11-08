/// Statistics and server metadata tools.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';

import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';
import 'arguments.dart';

const int _defaultMonths = 12;

const int _maxMonths = 120;

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
