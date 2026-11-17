library;

import 'package:flutter/foundation.dart' show internal;
import 'package:json_schema_builder/json_schema_builder.dart';

import 'arguments.dart';
import 'output_schemas.dart';
import 'schemas.dart';
import 'stats_payloads.dart';
import 'tool_def.dart';
import 'tool_values.dart';

@internal
final List<ToolDef> statsTools = [
  ToolDef(
    name: 'get_stats',
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
    output: _getStatsOutput,
    parse: (raw) =>
        ToolArguments('get_stats', raw).optionalInt('months', statsMonths),
    run: (months, ctx) async => ToolResult(
      await DiaryStatsPayloads(
        diaries: ctx.diaries,
        categories: ctx.categories,
        insights: ctx.insights,
      ).statsPayload(months: months),
    ),
  ),
];

final _getStatsOutput = objectSchema({
  for (final key in [
    'totalDiaries',
    'visibleDiaries',
    'recycleBinDiaries',
    'uncategorizedDiaries',
    'olderDiaries',
    'futureDiaries',
  ])
    key: integerOutputSchema,
  'firstDiaryTime': nullableStringOutputSchema,
  'lastDiaryTime': nullableStringOutputSchema,
  'months': listOutputSchema(
    objectSchema({'month': stringOutputSchema, 'diaries': integerOutputSchema}),
  ),
  'monthsWindow': objectSchema({
    'from': stringOutputSchema,
    'to': stringOutputSchema,
  }),
  'categories': listOutputSchema(
    objectSchema({
      'categoryId': stringOutputSchema,
      'categoryName': nullableStringOutputSchema,
      'diaries': integerOutputSchema,
    }),
  ),
  'moods': objectSchema({
    'distribution': objectSchema({
      for (final mood in toolMoodNames) mood: integerOutputSchema,
    }),
    'recordedDiaries': integerOutputSchema,
    'diariesWithoutMood': integerOutputSchema,
    'averageScore': S.combined(type: [JsonType.num, JsonType.nil]),
    'recordedDays': integerOutputSchema,
  }),
  'generatedAt': stringOutputSchema,
});
