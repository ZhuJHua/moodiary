/// Diary statistics tools.
library;

import 'package:flutter/foundation.dart' show internal;
import 'package:json_schema_builder/json_schema_builder.dart';

import 'arguments.dart';
import 'diary_references.dart';
import 'output_schemas.dart';
import 'schemas.dart';
import 'stats_payloads.dart';
import 'tool_def.dart';

@internal
final List<ToolDefinition> statsTools = [
  ToolDef(
    name: 'get_stats',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('get_stats', result.data),
    title: 'Diary statistics',
    description: (_) =>
        'Reports the diary totals (all rows, visible, recycle bin, '
        'uncategorized), the diary count per local calendar month for the '
        'last months, the count per category, the mood distribution of '
        'visible diaries (including not-recorded moods), and the first and last '
        'visible diary times. Prefer this over counting search rows for how many, '
        'which category, since when or mood-trend questions. monthsWindow names the '
        'months the bucket list covers; olderDiaries and futureDiaries count '
        'the visible diaries outside that window, so '
        'sum(months.diaries) + olderDiaries + futureDiaries == '
        'visibleDiaries always holds and no diary is missing from the sum.',
    input: (_) => S.object(properties: {'months': statsMonthsSchema}),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: toolOutputSchema('get_stats'),
    parse: _parseGetStats,
    run: (input, ctx) => _getStats(input, ctx),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
];

Future<ToolResult> _getStats(_GetStatsInput input, ToolContext ctx) async {
  final (:months) = input;
  return ToolResult(
    await DiaryStatsPayloads(
      diaries: ctx.diaries,
      categories: ctx.categories,
      insights: ctx.insights,
    ).statsPayload(months: months),
  );
}

typedef _GetStatsInput = ({int months});

_GetStatsInput _parseGetStats(Map<String, Object?> raw) {
  final args = ToolArguments('get_stats', raw);
  final months = args.optionalInt('months', fallback: 12, min: 1, max: 120);
  return (months: months);
}
