import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import 'js_sandbox.dart';
import 'memory_repository.dart';

final List<ToolDef> assistantToolDefinitions = List.unmodifiable([
  ...toolsFor(ToolSurface.assistant),
  ...assistantOnlyTools,
]);

ToolContext assistantToolContext() => ToolContext(
  diaries: getIt<DiaryRepository>(),
  categories: getIt<CategoryRepository>(),
  insights: getIt<MoodInsightsRepository>(),
  surface: ToolSurface.assistant,
  semantic: getIt.isRegistered<EmbedIndexService>()
      ? getIt<EmbedIndexService>()
      : null,
);

final List<ToolDef> assistantOnlyTools = [
  ToolDef<Map<String, Object?>>(
    name: 'recall_memory',
    title: 'Recall memory',
    surfaces: const {ToolSurface.assistant},
    effect: ToolEffect.read,
    idempotent: true,
    description: (_) =>
        'Look up what you saved about the user in earlier conversations. '
        'You are not given those facts otherwise. Pass a query describing '
        'what you need; leave it '
        'out for the most recent facts. Each row carries the id you need to '
        'revise or forget it. Do not call this for greetings or small talk.',
    input: (_) => S.object(
      properties: {
        'query': S.combined(type: [JsonType.string, JsonType.nil]),
        'limit': S.combined(
          type: [JsonType.int, JsonType.nil],
          description:
              'Result count, clamped to ${_memoryLimit.min}..${_memoryLimit.max}.',
          defaultValue: _memoryLimit.fallback,
        ),
      },
      additionalProperties: false,
    ),
    output: _recallMemoryOutput,
    parse: (raw) => raw,
    run: (raw, _) async {
      final repo = getIt<MemoryRepository>();
      final query = (raw['query'] as String? ?? '').trim();
      final limit = ((raw['limit'] as num?)?.toInt() ?? _memoryLimit.fallback)
          .clamp(_memoryLimit.min, _memoryLimit.max);
      final hits = query.isEmpty
          ? await repo.getRecent(limit)
          : await repo.search(query, limit: limit);
      return ToolResult({
        'facts': [
          for (final fact in hits)
            {'id': fact.id, 'category': fact.category, 'text': fact.text},
        ],
        'total': await repo.count(),
      });
    },
  ),
  ToolDef(
    name: 'remember_fact',
    title: 'Remember facts',
    surfaces: const {ToolSurface.assistant},
    effect: ToolEffect.write,
    idempotent: true,
    description: (_) =>
        'Save durable facts about the user — lasting preferences, recurring '
        'themes, ongoing goals. Only from what the user says about '
        'themselves or asks you to remember: never from a diary you read or '
        'any other tool result. Not passing details, one-off events, '
        'health, beliefs, legal or financial specifics, or anything they '
        'asked you to keep private or not remember. '
        'Pass an id to revise a fact instead of adding one. '
        '$toolBatchDescription Max 20 per call.',
    input: (_) => batchItemsSchema(
      objectSchema(
        {
          'id': nullableStringOutputSchema,
          'text': stringOutputSchema,
          'category': nullableStringOutputSchema,
          'source': nullableStringOutputSchema,
        },
        optional: ['id', 'category', 'source'],
      ),
    ),
    output: _factBatchOutput,
    parse: toolBatchItems,
    run: (items, _) => runToolBatch(items, _rememberFact),
  ),
  ToolDef(
    name: 'forget_fact',
    title: 'Forget facts',
    surfaces: const {ToolSurface.assistant},
    effect: ToolEffect.destructive,
    idempotent: true,
    description: (_) =>
        'Delete saved facts by id (from recall_memory). This is permanent — '
        'there is no recycle bin for memories. '
        '$toolBatchDescription Max 20 per call.',
    input: (_) => objectSchema({'ids': toolIdsSchema(stringOutputSchema)}),
    output: _factBatchOutput,
    parse: toolBatchIds,
    run: (items, _) => runToolBatch(items, (item) async {
      final id = item['id']! as String;
      if (!await getIt<MemoryRepository>().delete(id)) {
        throw ToolFailure('no memory with id=$id');
      }
      return ToolResult({'id': id});
    }),
  ),
  ToolDef<Map<String, Object?>>(
    name: 'run_javascript',
    title: 'Run JavaScript',
    surfaces: const {ToolSurface.assistant},
    effect: ToolEffect.read,
    idempotent: false,
    description: (_) =>
        'Run JavaScript (ES2023) to compute something — arithmetic across '
        'many numbers, date math, grouping, sorting. The result is the value '
        'of the LAST expression, so end with the value you want; you do not '
        'need `return`. `console.log/info/warn/error` is captured separately. '
        'Put all of it in one script: each call gets a fresh sandbox that '
        'remembers nothing from the last one.\n'
        'The sandbox is bare: no network, no filesystem, no timers, no '
        'require, and NO access to the diaries — pass any data you need in as '
        'literals in the code, having read it with the other tools first. '
        'Runs are capped at a couple of seconds and a few MB; an endless loop '
        'is killed, not waited for.',
    input: (_) => objectSchema({'code': stringOutputSchema}),
    output: _javascriptOutput,
    parse: (raw) {
      if ((raw['code']! as String).trim().isEmpty) {
        throw const ToolArgumentException(
          'run_javascript: code must not be empty',
        );
      }
      return raw;
    },
    run: (raw, _) async {
      final result = await JsSandbox.run(raw['code']! as String);
      return ToolResult({
        'value': result.value,
        'logs': result.logs,
        'truncated': result.truncated,
      });
    },
  ),
];

final _factBatchOutput = batchOutputSchema(
  objectSchema(
    {
      'id': stringOutputSchema,
      'text': stringOutputSchema,
      'category': stringOutputSchema,
      'duplicate': S.boolean(),
    },
    optional: ['id', 'text', 'category', 'duplicate'],
  ),
);

Future<ToolResult> _rememberFact(Map<String, Object?> raw) async {
  final text = (raw['text']! as String).trim();
  if (text.isEmpty) throw const ToolFailure('the fact cannot be empty');
  final rawCategory = (raw['category'] as String? ?? 'fact').trim();
  final category =
      const {'preference', 'theme', 'goal', 'fact'}.contains(rawCategory)
      ? rawCategory
      : 'fact';
  final repo = getIt<MemoryRepository>();
  final id = (raw['id'] as String? ?? '').trim();
  if (id.isNotEmpty) {
    final current = await repo.get(id);
    if (current == null) throw ToolFailure('no memory with id=$id');
    await repo.put(
      current.copyWith(text: text, category: category, updatedAt: .timestamp()),
    );
    return ToolResult({'id': id, 'text': text, 'category': category});
  }
  final duplicate = await repo.findDuplicate(category, text);
  if (duplicate != null) {
    await repo.touch(duplicate.id);
    return ToolResult({
      'id': duplicate.id,
      'text': duplicate.text,
      'category': category,
      'duplicate': true,
    });
  }
  final source = (raw['source'] as String?)?.trim();
  final fact = MemoryEntry.create(
    category: category,
    text: text,
    source: const {'user_said', 'user_asked'}.contains(source)
        ? source
        : 'user_said',
  );
  await repo.put(fact);
  return ToolResult({'id': fact.id, 'text': text, 'category': category});
}

final _recallMemoryOutput = objectSchema({
  'facts': S.list(
    items: objectSchema({
      'id': stringOutputSchema,
      'category': stringOutputSchema,
      'text': stringOutputSchema,
    }),
  ),
  'total': S.integer(),
});

final _javascriptOutput = objectSchema({
  'value': stringOutputSchema,
  'logs': S.list(items: stringOutputSchema),
  'truncated': S.boolean(),
});

const _memoryLimit = (fallback: 8, min: 1, max: 8);
