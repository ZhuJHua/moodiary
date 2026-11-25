import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_assistant/src/assistant_providers.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_semantic/moodiary_semantic.dart';
import 'package:moodiary_tools/moodiary_tools.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'memory_repository.dart';

final List<ToolDef> assistantToolDefinitions = List.unmodifiable([
  ...toolsFor(ToolSurface.assistant),
  ...assistantOnlyTools,
]);

class AssistantToolContext extends ToolContext {
  AssistantToolContext({
    required super.diaries,
    required super.categories,
    required super.tags,
    required super.insights,
    required super.semantic,
    required super.heifDecoder,
    required this.memory,
  }) : super(surface: ToolSurface.assistant);
  final MemoryRepository memory;
}

AssistantToolContext assistantToolContext(Ref ref) => AssistantToolContext(
  diaries: ref.watch(diaryRepositoryProvider),
  categories: ref.watch(categoryRepositoryProvider),
  tags: ref.watch(tagRepositoryProvider),
  insights: ref.watch(moodInsightsRepositoryProvider),
  memory: ref.watch(memoryRepositoryProvider),
  semantic: ref.watch(embedIndexServiceProvider),
  heifDecoder: ref.watch(heifDecoderProvider),
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
    run: (raw, context) async {
      final repo = (context as AssistantToolContext).memory;
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
    run: (items, context) => runToolBatch(
      items,
      (item) => _rememberFact(item, (context as AssistantToolContext).memory),
    ),
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
    run: (items, context) => runToolBatch(items, (item) async {
      final id = item['id']! as String;
      if (!await (context as AssistantToolContext).memory.delete(id)) {
        throw ToolFailure('no memory with id=$id');
      }
      return ToolResult({'id': id});
    }),
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

Future<ToolResult> _rememberFact(
  Map<String, Object?> raw,
  MemoryRepository repo,
) async {
  final text = (raw['text']! as String).trim();
  if (text.isEmpty) throw const ToolFailure('the fact cannot be empty');
  final rawCategory = (raw['category'] as String? ?? 'fact').trim();
  final category =
      const {'preference', 'theme', 'goal', 'fact'}.contains(rawCategory)
      ? rawCategory
      : 'fact';
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

const _memoryLimit = (fallback: 8, min: 1, max: 8);
