import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/js_sandbox.dart';
import 'package:moodiary_assistant/src/data/memory_repository.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

typedef AssistantToolRun = Future<String> Function(Map<String, dynamic> input);

typedef _KeywordSearch = ({
  List<Diary> results,
  int total,
  List<String> keywords,
  String? categoryId,
  DateTime? start,
  DateTime? endExclusive,
});

typedef _SearchRow = ({Diary diary, bool keyword, bool meaning, double? score});

const String _failurePrefix = 'Failed:';

typedef AssistantToolSummarize = String Function(
  AssistantTool tool,
  Map<String, dynamic> input,
  String output,
);

class AssistantToolSpec {
  final AssistantTool tool;
  final String description;
  final Map<String, dynamic> jsonSchema;
  final AssistantToolRun run;

  final AssistantToolSummarize? summarize;

  final bool replayResult;

  const AssistantToolSpec({
    required this.tool,
    required this.description,
    required this.jsonSchema,
    required this.run,
    this.summarize,
    this.replayResult = false,
  });

  String summaryOf(Map<String, dynamic> input, String output) {
    if (output.startsWith(_failurePrefix)) return l10n.assistant.toolFailed;
    if (output.startsWith(assistantToolSkippedPrefix)) {
      return l10n.assistant.toolSkipped;
    }
    final custom = summarize?.call(tool, input, output);
    if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    return l10n.assistant.toolDone;
  }

  String get id => tool.id;
}

abstract final class AssistantToolRegistry {
  static const _defaultQueryLimit = 8;

  static const _maxQueryLimit = 20;

  static const _defaultRecallLimit = 8;

  static const _maxRecallLimit = 8;

  static const _maxExcerptLength = 200;

  static const _maxFullContentLength = 4000;

  static const _maxBatchRead = 10;

  static const _maxBatchWrite = _maxQueryLimit;

  static final List<AssistantToolSpec> specs = [
    const AssistantToolSpec(
      tool: .searchDiaries,
      description:
          'Search or browse the diaries stored on this device. Every argument '
          'is an optional filter. Give a query to search and it runs both the '
          'keyword path and, where the local semantic index is on, a '
          'meaning-based one, merged into a single ranking; leave it out to '
          'browse by date and/or category. Each row says how it was found '
          '(via=keyword, meaning, or both). '
          'Results carry id, date, mood and a short excerpt — not the full '
          'text (use getDiary for that) — and state the total number of '
          'matches, which may exceed what is returned; when it does, say so '
          'instead of presenting the rows as the complete set. '
          'Mood is one of a fixed set of emotion/state values (see the mood '
          'enum on createDiary); neutral is also the default for entries whose '
          'mood was never set, so do not over-read it. '
          'Call this whenever the user asks about what they wrote, and to get '
          'ids before editing or deleting entries.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'What to look for: keywords, or a sentence describing the '
                'entry. Keyword terms combine with AND — every term must '
                'appear, so prefer one or two specific words over a list of '
                'synonyms. Pinyin and initials match Chinese text. Omit to '
                'browse by the filters below.',
          },
          'categoryId': {
            'type': 'string',
            'description': 'Restrict to one category (id from listCategories).',
          },
          'startDate': {
            'type': 'string',
            'description':
                'Inclusive start, YYYY-MM-DD in the user local time.',
          },
          'endDate': {
            'type': 'string',
            'description': 'Inclusive end, YYYY-MM-DD in the user local time.',
          },
          'sort': {
            'type': 'string',
            'enum': ['newest', 'oldest', 'modified', 'relevance'],
            'description':
                'Defaults to relevance with a query, newest without one. '
                'relevance needs a query; modified applies only without one.',
          },
          'mode': {
            'type': 'string',
            'enum': ['auto', 'keyword', 'meaning'],
            'description':
                'Defaults to auto. Force one path only when you have a reason.',
          },
          'limit': {
            'type': 'integer',
            'description': 'How many entries to return. Default 8, max 20.',
            'minimum': 1,
            'maximum': 20,
          },
        },
      },
      run: _searchDiaries,
      summarize: _summarizeQuery,
    ),
    const AssistantToolSpec(
      tool: .getDiary,
      description:
          'Read the full text of diaries by id (searchDiaries returns excerpts only). '
          'Pass every id you need in one call. Max $_maxBatchRead per call.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'ids': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Diary ids from searchDiaries. Max $_maxBatchRead.',
          },
        },
        'required': ['ids'],
      },
      run: _getDiary,
      summarize: _summarizeGet,
    ),
    const AssistantToolSpec(
      tool: .diaryOverview,
      description:
          'Aggregate stats: total entries, per-category counts, the date span, and '
          'the mood distribution. Prefer this over counting query results yourself '
          'for "how many", "which category", "since when" or mood-trend questions.',
      jsonSchema: {'type': 'object', 'properties': {}},
      run: _diaryOverview,
      summarize: _summarizeOverview,
    ),
    AssistantToolSpec(
      tool: .createDiary,
      description:
          'Save content as new diaries. Call this when the user asks you to '
          'write something down or to keep it as an entry. Bodies are Markdown.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'description':
                'One object per diary. Pass them all in one call. '
                'Max $_maxBatchWrite per call.',
            'items': {
              'type': 'object',
              'properties': {
                'title': {'type': 'string', 'description': 'Optional title.'},
                'content': {'type': 'string', 'description': 'Body, Markdown.'},
                'mood': {
                  'type': 'string',
                  'enum': [for (final m in DiaryMood.values) m.name],
                  'description':
                      'Mood or life-state of the entry. Omit unless the user '
                      'conveyed one.',
                },
                'categoryId': {
                  'type': 'string',
                  'description': 'Optional category id from listCategories.',
                },
              },
              'required': ['content'],
            },
          },
        },
        'required': ['items'],
      },
      run: _createDiary,
      summarize: _summarizeWrite,
    ),
    AssistantToolSpec(
      tool: .updateDiary,
      description:
          'Edit diaries by id. Within an item, only the fields you pass change; '
          'the rest are left alone. Pass every edit in one call. Get the ids '
          'from searchDiaries first.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'description':
                'One object per diary to edit. Max $_maxBatchWrite per call.',
            'items': {
              'type': 'object',
              'properties': {
                'id': {
                  'type': 'string',
                  'description': 'Diary id from searchDiaries.',
                },
                'title': {'type': 'string', 'description': 'New title.'},
                'content': {
                  'type': 'string',
                  'description': 'New body, Markdown.',
                },
                'mood': {
                  'type': 'string',
                  'enum': [for (final m in DiaryMood.values) m.name],
                  'description': 'New mood.',
                },
                'categoryId': {
                  'type': 'string',
                  'description': 'New category id.',
                },
              },
              'required': ['id'],
            },
          },
        },
        'required': ['items'],
      },
      run: _updateDiary,
      summarize: _summarizeWrite,
    ),
    const AssistantToolSpec(
      tool: .deleteDiary,
      description:
          'Move diaries to the recycle bin by id, where the user can restore '
          'them. Pass every id in one call. Get the ids from searchDiaries '
          'first. Max $_maxBatchWrite per call.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'ids': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Diary ids from searchDiaries. Max $_maxBatchWrite.',
          },
        },
        'required': ['ids'],
      },
      run: _deleteDiary,
      summarize: _summarizeDelete,
    ),
    const AssistantToolSpec(
      tool: .listCategories,
      description:
          'List every diary category with its id. Call this to get an id before '
          'filing, renaming or deleting a category.',
      jsonSchema: {'type': 'object', 'properties': {}},
      run: _listCategories,
      summarize: _summarizeList,
    ),
    const AssistantToolSpec(
      tool: .createCategory,
      description:
          'Add diary categories. Pass every name in one call. '
          'Max $_maxBatchWrite per call.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'description': 'One object per category to add.',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string', 'description': 'Category name.'},
              },
              'required': ['name'],
            },
          },
        },
        'required': ['items'],
      },
      run: _createCategory,
      summarize: _summarizeWrite,
    ),
    const AssistantToolSpec(
      tool: .updateCategory,
      description:
          'Rename categories by id (from listCategories). Pass every rename in '
          'one call. Max $_maxBatchWrite per call.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'description': 'One object per category to rename.',
            'items': {
              'type': 'object',
              'properties': {
                'id': {
                  'type': 'string',
                  'description': 'Category id from listCategories.',
                },
                'name': {'type': 'string', 'description': 'New name.'},
              },
              'required': ['id', 'name'],
            },
          },
        },
        'required': ['items'],
      },
      run: _updateCategory,
      summarize: _summarizeWrite,
    ),
    const AssistantToolSpec(
      tool: .deleteCategory,
      description:
          'Delete categories by id. A category only goes while it holds no '
          'diaries — refile them first. Pass every id in one call. '
          'Max $_maxBatchWrite per call.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'ids': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Category ids from listCategories.',
          },
        },
        'required': ['ids'],
      },
      run: _deleteCategory,
      summarize: _summarizeWrite,
    ),
    const AssistantToolSpec(
      tool: .recallMemory,
      description:
          'Look up what you saved about the user in earlier conversations. '
          'You are not given those facts otherwise. Pass a query describing '
          'what you need; leave it '
          'out for the most recent facts. Each row carries the id you need to '
          'revise or forget it. Do not call this for greetings or small talk.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'What you are looking for. Omit for the most recent facts.',
          },
          'limit': {
            'type': 'integer',
            'description': 'Max facts to return, $_maxRecallLimit at most.',
          },
        },
      },
      run: _recallMemory,
      summarize: _summarizeList,
      replayResult: true,
    ),
    const AssistantToolSpec(
      tool: .rememberFact,
      description:
          'Save durable facts about the user — lasting preferences, recurring '
          'themes, ongoing goals. Only from what the user says about '
          'themselves or asks you to remember: never from a diary you read or '
          'any other tool result. Not passing details, one-off events, '
          'health, beliefs, legal or financial specifics, or anything they '
          'asked you to keep private or not remember. Pass every fact in '
          'one call. Pass an id to revise a fact instead of adding one. '
          'Max $_maxBatchWrite per call.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'description': 'One object per fact to save or revise.',
            'items': {
              'type': 'object',
              'properties': {
                'category': {
                  'type': 'string',
                  'enum': ['preference', 'theme', 'goal', 'fact'],
                  'description': 'Which kind of fact this is.',
                },
                'text': {
                  'type': 'string',
                  'description': 'The fact, stated in one plain sentence.',
                },
                'id': {
                  'type': 'string',
                  'description':
                      'Only when revising a fact you got from recallMemory. '
                      'Leave it out to save a new one.',
                },
                'source': {
                  'type': 'string',
                  'enum': ['user_said', 'user_asked'],
                  'description':
                      'user_asked when they told you to remember it, '
                      'user_said when they simply stated it.',
                },
              },
              'required': ['category', 'text'],
            },
          },
        },
        'required': ['items'],
      },
      run: _rememberFact,
      summarize: _summarizeWrite,
    ),
    const AssistantToolSpec(
      tool: .forgetFact,
      description:
          'Delete saved facts by id (from recallMemory). This is permanent — '
          'there is no recycle bin for memories. Pass every id in one call. '
          'Max $_maxBatchWrite per call.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'ids': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Memory ids from recallMemory.',
          },
        },
        'required': ['ids'],
      },
      run: _forgetFact,
      summarize: _summarizeWrite,
    ),
    const AssistantToolSpec(
      tool: .runJavascript,
      description:
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
      jsonSchema: {
        'type': 'object',
        'properties': {
          'code': {
            'type': 'string',
            'description':
                'The script. Ends with the expression whose value you want.',
          },
        },
        'required': ['code'],
      },
      run: _runJavascript,
      summarize: _summarizeJavascript,
    ),
  ];

  static const _maxReplayChars = 600;

  static bool get semanticAvailable =>
      getIt.isRegistered<EmbedIndexService>() &&
      getIt<EmbedIndexService>().enabled;

  static String recordOf(List<AssistantToolCall> calls) {
    final lines = <String>[];
    for (final call in calls) {
      if (!call.done) continue;
      final spec = byId(call.name);
      final args = call.argsJson.isEmpty ? '{}' : call.argsJson;
      if (spec != null && spec.replayResult && call.result.isNotEmpty) {
        final body = call.result.length > _maxReplayChars
            ? '${call.result.substring(0, _maxReplayChars)}…'
            : call.result;
        lines.add('- ${call.name}($args) →\n$body');
        continue;
      }
      final summary = spec == null
          ? ''
          : spec.summaryOf(_decodeArgs(call.argsJson), call.result);
      lines.add('- ${call.name}($args)${summary.isEmpty ? '' : ' → $summary'}');
    }
    return lines.isEmpty ? '' : '[tools already run]\n${lines.join('\n')}';
  }

  static Map<String, dynamic> _decodeArgs(String raw) {
    if (raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : const {};
    } catch (_) {
      return const {};
    }
  }

  static AssistantToolSpec? byId(String id) {
    for (final spec in specs) {
      if (spec.id == id) return spec;
    }
    return null;
  }

  static List<AssistantToolSpec> specsFor(List<String>? allowed) {
    if (allowed == null) return specs;
    return [
      for (final spec in specs)
        if (allowed.contains(spec.id)) spec,
    ];
  }

  static String _summarizeQuery(
    AssistantTool _,
    Map<String, dynamic> input,
    String output,
  ) {
    final hit = RegExp(r'^(\d+) matches').firstMatch(output);
    if (hit == null) return l10n.assistant.toolNoMatch;
    final count = int.tryParse(hit.group(1) ?? '') ?? 0;
    final parts = <String>[
      l10n.assistant.toolMatched(count: count),
      ?_trimToNull(input['query']),
      if (_trimToNull(input['startDate']) case final a?)
        _trimToNull(input['endDate']) == null ? a : '$a – ${input['endDate']}',
    ];
    return parts.join(' · ');
  }

  static String _summarizeGet(
    AssistantTool _,
    Map<String, dynamic> input,
    String _,
  ) => l10n.assistant.toolRead(count: assistantToolIds(input).length);

  static String _summarizeOverview(
    AssistantTool _,
    Map<String, dynamic> _,
    String output,
  ) {
    final hit = RegExp(r'^Total entries=(\d+)').firstMatch(output);
    final count = int.tryParse(hit?.group(1) ?? '') ?? 0;
    return l10n.assistant.toolMatched(count: count);
  }

  static String _summarizeList(
    AssistantTool _,
    Map<String, dynamic> _,
    String output,
  ) {
    final count = output.split('\n').where((e) => e.startsWith('id=')).length;
    return count == 0
        ? l10n.assistant.toolNoMatch
        : l10n.assistant.toolListed(count: count);
  }

  static String _summarizeDelete(
    AssistantTool _,
    Map<String, dynamic> input,
    String _,
  ) {
    final count = assistantToolItems(input).length;
    return count <= 1
        ? l10n.assistant.toolTrashed
        : l10n.assistant.toolTrashedCount(count: count);
  }

  static String _summarizeWrite(
    AssistantTool tool,
    Map<String, dynamic> input,
    String output,
  ) {
    final items = assistantToolItems(input);
    if (items.length > 1) {
      return switch (tool) {
        .createDiary ||
        .updateDiary => l10n.assistant.toolBatchDiaries(count: items.length),
        _ => l10n.assistant.toolBatchItems(count: items.length),
      };
    }
    final item = items.isEmpty ? const <String, dynamic>{} : items.first;
    return switch (tool) {
      .createDiary => _trimToNull(item['title']) ?? l10n.assistant.toolUntitled,
      .createCategory ||
      .updateCategory => _trimToNull(item['name']) ?? l10n.assistant.toolDone,
      .rememberFact => _trimToNull(item['text']) ?? l10n.assistant.toolDone,
      .deleteCategory || .forgetFact => l10n.assistant.toolDeleted,
      _ => l10n.assistant.toolUpdated,
    };
  }

  static Future<_KeywordSearch> _keywordSearch(
    Map<String, dynamic> input,
  ) async {
    final rawKeywords = ((input['query'] as String?) ?? '').trim();
    final keywordsForDisplay = rawKeywords
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final categoryId = _trimToNull(input['categoryId']);
    final sortName = (input['sort'] as String?)?.trim();
    final limit = _parseLimit(input['limit']);
    final start = _parseDate(input['startDate']);
    final endExclusive = _parseDate(input['endDate'])
        ?.add(const Duration(days: 1));

    final repo = getIt<DiaryRepository>();
    List<Diary> results;
    int? total;
    if (rawKeywords.isNotEmpty) {
      final hits = await repo.searchDiaries(
        query: rawKeywords,
        categoryId: categoryId,
        start: start,
        end: endExclusive,
        sort: _toSearchSort(sortName),
        limit: limit,
      );
      results = [for (final hit in hits) hit.diary];
      if (results.length >= limit) {
        total = await repo.countSearchDiaries(
          query: rawKeywords,
          categoryId: categoryId,
          start: start,
          end: endExclusive,
        );
      }
    } else if (start != null || endExclusive != null) {
      final ranged = await repo.getDiariesByDateRange(
        start ?? .fromMillisecondsSinceEpoch(0),
        endExclusive ?? DateTime.now().add(const Duration(days: 1)),
      );
      results =
          ranged
              .where((d) => categoryId == null || d.categoryId == categoryId)
              .where((d) => _inRange(d.time, start, endExclusive))
              .toList()
            ..sort(_diaryComparator(sortName));
    } else {
      results = await repo.getDiaryByCategory(
        categoryId: categoryId,
        sort: _toDiarySort(sortName),
        limit: limit,
      );
    }

    return (
      results: results,
      total: total ?? results.length,
      keywords: keywordsForDisplay,
      categoryId: categoryId,
      start: start,
      endExclusive: endExclusive,
    );
  }

  static Future<List<SemanticHit>> _semanticHits(
    Map<String, dynamic> input, {
    required int limit,
  }) async {
    final query = ((input['query'] as String?) ?? '').trim();
    if (query.isEmpty) return const [];
    if (!semanticAvailable) return const [];
    final index = getIt<EmbedIndexService>();
    final categoryId = _trimToNull(input['categoryId']);
    final start = _parseDate(input['startDate']);
    final endExclusive = _parseDate(input['endDate'])
        ?.add(const Duration(days: 1));
    return index.search(
      query,
      limit: limit,
      categoryId: categoryId,
      start: start,
      endExclusive: endExclusive,
    );
  }

  static Future<String> _searchDiaries(Map<String, dynamic> input) async {
    final mode = (input['mode'] as String?)?.trim() ?? 'auto';
    final limit = _parseLimit(input['limit']);
    final hasQuery = ((input['query'] as String?) ?? '').trim().isNotEmpty;
    final semanticOn = hasQuery && semanticAvailable;
    final wantKeyword = mode != 'meaning';
    final wantMeaning = mode != 'keyword' && semanticOn;

    final keyword = wantKeyword
        ? await _keywordSearch(input)
        : (
            results: <Diary>[],
            total: 0,
            keywords: <String>[],
            categoryId: _trimToNull(input['categoryId']),
            start: _parseDate(input['startDate']),
            endExclusive: _parseDate(input['endDate'])
                ?.add(const Duration(days: 1)),
          );

    final hits = wantMeaning
        ? await _semanticHits(input, limit: limit)
        : const <SemanticHit>[];

    final rows = _fuse(keyword.results, hits, limit: limit);
    if (rows.isEmpty) {
      final base = await _emptyQueryMessage(
        keyword.keywords,
        keyword.categoryId,
        keyword.start,
        keyword.endExclusive,
      );
      final how = !hasQuery
          ? ''
          : wantMeaning
          ? ' Both the keyword and the meaning path ran.'
          : semanticOn
          ? ' Only the keyword path ran.'
          : ' Only the keyword path ran; the semantic index is off.';
      return '$base$how';
    }
    final repo = getIt<DiaryRepository>();
    final resolved = <_SearchRow>[];
    for (final row in rows) {
      if (row.diary != null) {
        resolved.add((
          diary: row.diary!,
          keyword: row.keyword,
          meaning: row.meaning,
          score: row.score,
        ));
        continue;
      }
      final diary = await repo.getDiaryByBusinessId(row.id);
      if (diary == null) continue;
      resolved.add((
        diary: diary,
        keyword: row.keyword,
        meaning: row.meaning,
        score: row.score,
      ));
    }
    return _formatSearchRows(
      resolved,
      total: keyword.total + hits.length - _overlap(keyword.results, hits),
      atLeast: wantMeaning && hits.length >= limit,
    );
  }

  static int _overlap(List<Diary> diaries, List<SemanticHit> hits) {
    final ids = {for (final d in diaries) d.id};
    var n = 0;
    for (final h in hits) {
      if (ids.contains(h.diaryId)) n++;
    }
    return n;
  }

  static List<
    ({String id, Diary? diary, bool keyword, bool meaning, double? score})
  >
  _fuse(List<Diary> keyword, List<SemanticHit> hits, {required int limit}) {
    const k = 60;
    final score = <String, double>{};
    final byId = <String, Diary>{};
    final fromKeyword = <String>{};
    final fromMeaning = <String>{};
    final similarity = <String, double>{};
    for (var i = 0; i < keyword.length; i++) {
      final d = keyword[i];
      byId[d.id] = d;
      fromKeyword.add(d.id);
      score[d.id] = (score[d.id] ?? 0) + 1 / (k + i + 1);
    }
    for (var i = 0; i < hits.length; i++) {
      final h = hits[i];
      fromMeaning.add(h.diaryId);
      similarity[h.diaryId] = (1 - h.distance).clamp(-1.0, 1.0);
      score[h.diaryId] = (score[h.diaryId] ?? 0) + 1 / (k + i + 1);
    }
    final ids = score.keys.toList()
      ..sort((a, b) => score[b]!.compareTo(score[a]!));
    return [
      for (final id in ids.take(limit))
        (
          id: id,
          diary: byId[id],
          keyword: fromKeyword.contains(id),
          meaning: fromMeaning.contains(id),
          score: similarity[id],
        ),
    ];
  }

  static String _formatSearchRows(
    List<_SearchRow> rows, {
    required int total,
    bool atLeast = false,
  }) {
    final count = atLeast ? 'at least $total' : '$total';
    final buffer = StringBuffer()
      ..writeln(
        rows.length < total || atLeast
            ? '$count matches; the first ${rows.length} follow. Raise limit or '
                  'narrow the filters for more.'
            : '$total matches:',
      );
    for (final row in rows) {
      final diary = row.diary;
      final title = diary.title.trim().isEmpty
          ? 'Untitled'
          : diary.title.trim();
      final cat = diary.categoryId;
      final catPart = (cat != null && cat.isNotEmpty) ? ' categoryId=$cat' : '';
      final via = row.keyword && row.meaning
          ? 'keyword+meaning'
          : row.meaning
          ? 'meaning'
          : 'keyword';
      final sim = row.meaning && row.score != null
          ? ' similarity=${row.score!.toStringAsFixed(2)}'
          : '';
      buffer.writeln(
        'id=${diary.id} 【${TimeFormat.isoDate(diary.time)}】$title '
        'mood=${diary.mood.name} via=$via$sim$catPart',
      );
      final text = diary.contentText.trim();
      if (text.isNotEmpty) {
        buffer.writeln(
          text.length > _maxExcerptLength
              ? '${text.substring(0, _maxExcerptLength)}… (excerpt; full text via getDiary)'
              : text,
        );
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  static Future<String> _getDiary(Map<String, dynamic> input) async {
    final ids = assistantToolIds(input);
    if (ids.isEmpty) {
      return 'Failed: no diary id given. Get ids from searchDiaries first.';
    }

    final repo = getIt<DiaryRepository>();
    final chunks = <String>[];
    final missing = <String>[];
    for (final id in ids.take(_maxBatchRead)) {
      final diary = await repo.getDiaryByBusinessId(id);
      if (diary == null || !diary.show) {
        missing.add(id);
        continue;
      }
      chunks.add(_formatDiaryFull(diary));
    }

    final buffer = StringBuffer();
    if (missing.isNotEmpty) {
      buffer.writeln(
        'Not found (deleted, or the id is wrong — recheck with searchDiaries): '
        '${missing.join(', ')}',
      );
      if (chunks.isNotEmpty) buffer.writeln();
    }
    if (ids.length > _maxBatchRead) {
      buffer.writeln(
        '(Only the first $_maxBatchRead were read; call again for the rest.)',
      );
    }
    buffer.write(chunks.join('\n\n---\n\n'));
    final out = buffer.toString().trim();
    return out.isEmpty ? 'Failed: none of those ids match a diary.' : out;
  }

  static String _formatDiaryFull(Diary diary) {
    final title = diary.title.trim().isEmpty ? 'Untitled' : diary.title.trim();
    final buffer = StringBuffer()
      ..writeln('id=${diary.id}')
      ..writeln('date=${TimeFormat.isoDate(diary.time)}')
      ..writeln('title=$title')
      ..writeln('mood=${diary.mood.name}');
    if (diary.categoryId != null && diary.categoryId!.isNotEmpty) {
      buffer.writeln('categoryId=${diary.categoryId}');
    }
    if (diary.tags.isNotEmpty) {
      buffer.writeln('tags=${diary.tags.join(', ')}');
    }
    final text = diary.contentText.trim();
    buffer
      ..writeln('body:')
      ..writeln(
        text.isEmpty
            ? '(empty)'
            : (text.length > _maxFullContentLength
                  ? '${text.substring(0, _maxFullContentLength)}'
                        '… (truncated, '
                        '${text.length - _maxFullContentLength} more characters)'
                  : text),
      );
    return buffer.toString().trim();
  }

  @visibleForTesting
  static Future<String> runBatch(
    Map<String, dynamic> input, {
    required Future<String> Function(Map<String, dynamic> item) each,
    int cap = _maxBatchWrite,
  }) async {
    final items = assistantToolItems(input);
    if (items.isEmpty) return '$_failurePrefix no items given.';
    final done = <String>[];
    final failed = <String>[];
    var index = 0;
    for (final item in items.take(cap)) {
      index++;
      String line;
      try {
        line = await each(item);
      } catch (e) {
        final id = item['id'];
        line =
            '$_failurePrefix ${id == null ? 'item $index' : 'id=$id'} '
            'threw $e.';
      }
      (line.startsWith(_failurePrefix) ? failed : done).add(line);
    }
    return _batchResult(
      done: done,
      failed: failed,
      requested: items.length,
      cap: cap,
    );
  }

  static String _batchResult({
    required List<String> done,
    required List<String> failed,
    required int requested,
    required int cap,
  }) {
    final tail = requested > cap
        ? '\n(Only the first $cap were processed; call again for the rest.)'
        : '';
    if (done.isEmpty) {
      final reasons = failed.map(_stripFailure).where((e) => e.isNotEmpty);
      return '$_failurePrefix ${reasons.join(' ')}'.trim() + tail;
    }
    final buffer = StringBuffer(done.join('\n'));
    if (failed.isNotEmpty) buffer.write('\n${failed.join('\n')}');
    buffer.write(tail);
    return buffer.toString();
  }

  static String _stripFailure(String line) => line.startsWith(_failurePrefix)
      ? line.substring(_failurePrefix.length).trim()
      : line;

  static Future<String> _diaryOverview(Map<String, dynamic> input) async {
    final repo = getIt<DiaryRepository>();
    final counts = await repo.diaryCountByCategory();
    if (counts.total == 0) return 'No diaries yet.';

    final cats = await getIt<CategoryRepository>().getAllCategories();
    final nameById = {for (final c in cats) c.id: c.categoryName};
    final newest = await repo.getDiaryByCategory(sort: .timeDesc, limit: 1);
    final oldest = await repo.getDiaryByCategory(sort: .timeAsc, limit: 1);

    final buffer = StringBuffer()..writeln('Total entries=${counts.total}');
    if (newest.isNotEmpty && oldest.isNotEmpty) {
      buffer.writeln(
        'span=${TimeFormat.isoDate(oldest.first.time)} ~ '
        '${TimeFormat.isoDate(newest.first.time)}',
      );
    }
    final categorized = counts.byCategory.values.fold<int>(0, (a, b) => a + b);
    final uncategorized = counts.total - categorized;
    buffer.writeln('by category:');
    if (counts.byCategory.isEmpty) {
      buffer.writeln('- (all uncategorised)');
    } else {
      final entries = counts.byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in entries) {
        final name = nameById[e.key] ?? '(deleted category)';
        buffer.writeln('- $name (id=${e.key}): ${e.value}');
      }
    }
    if (uncategorized > 0) buffer.writeln('- uncategorised: $uncategorized');

    final moods = await repo.getDiaryByCategory(sort: .timeDesc, limit: 9999);
    if (moods.isNotEmpty) {
      final counts = <DiaryMood, int>{};
      for (final d in moods) {
        counts[d.mood] = (counts[d.mood] ?? 0) + 1;
      }
      buffer
        ..writeln(
          'mood distribution (neutral is also the default for entries whose '
          'mood was never set):',
        )
        ..writeln(
          '- ${[for (final m in DiaryMood.values)
            if ((counts[m] ?? 0) > 0 || m == DiaryMood.neutral) '${m.name}=${counts[m] ?? 0}'].join(', ')}',
        );
    }
    return buffer.toString().trim();
  }

  static Future<String> _createDiary(Map<String, dynamic> input) =>
      runBatch(input, each: _createOneDiary);

  static Future<String> _createOneDiary(Map<String, dynamic> input) async {
    final title = (input['title'] as String?)?.trim() ?? '';
    final content = (input['content'] as String?)?.trim() ?? '';
    if (content.isEmpty) return 'Failed: the body cannot be empty.';

    final mood = _parseMood(input['mood']) ?? DiaryMood.neutral;
    final categoryId = await _resolveCategoryId(input['categoryId']);

    final converted = _toTiptap(content);
    final diary = Diary.create(
      categoryId: categoryId,
      title: title,
      content: converted.content,
      contentText: converted.contentText,
      mood: mood,
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: const [],
      type: converted.type,
      aspect: null,
    );
    await getIt<DiaryRepository>().insertADiary(diary);
    return 'Created "${title.isEmpty ? 'Untitled' : title}" '
        '(${TimeFormat.isoDate(diary.time)}), id=${diary.id}.';
  }

  static ({String content, String contentText, DiaryType type}) _toTiptap(
    String markdown,
  ) {
    final json = MarkdownToTiptap.convert(markdown);
    if (json != null && json.isNotEmpty) {
      return (
        content: json,
        contentText: TiptapContent.parse(json).plainText,
        type: DiaryType.tiptap,
      );
    }
    return (
      content: markdown,
      contentText: MarkdownConverter.convert(markdown),
      type: DiaryType.markdown,
    );
  }

  static Future<String> _updateDiary(Map<String, dynamic> input) =>
      runBatch(input, each: _updateOneDiary);

  static Future<String> _updateOneDiary(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return 'Failed: no diary id given.';

    final repo = getIt<DiaryRepository>();
    final existing = await repo.getDiaryByBusinessId(id);
    if (existing == null || !existing.show) {
      return 'Failed: no diary with id=$id.';
    }

    var updated = existing;
    final title = input['title'] as String?;
    if (title != null) updated = updated.copyWith(title: title.trim());
    final content = input['content'] as String?;
    if (content != null) {
      final converted = _toTiptap(content);
      updated = updated.copyWith(
        content: converted.content,
        contentText: converted.contentText,
        type: converted.type.value,
      );
      // 内容变更必须重算媒体引用，否则媒体库留下幻影条目
      updated = withDerivedMedia(updated);
    }
    final mood = _parseMood(input['mood']);
    if (mood != null) updated = updated.copyWith(mood: mood);
    if (input.containsKey('categoryId')) {
      final rawCategory = (input['categoryId'] as String?)?.trim() ?? '';
      if (rawCategory.isEmpty) {
        updated = updated.copyWith(categoryId: null);
      } else {
        final resolved = await _resolveCategoryId(rawCategory);
        if (resolved == null) {
          return 'Failed: no category with id=$rawCategory (check listCategories).';
        }
        updated = updated.copyWith(categoryId: resolved);
      }
    }
    updated = touched(updated);

    await repo.updateADiary(
      newDiary: updated,
      index: (title == null && content == null) ? .skip : .inline,
    );
    final shown = updated.title.trim().isEmpty
        ? 'Untitled'
        : updated.title.trim();
    return 'Updated "$shown" (id=$id).';
  }

  static Future<String> _deleteDiary(Map<String, dynamic> input) =>
      runBatch(input, each: _deleteOneDiary);

  static Future<String> _deleteOneDiary(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return 'Failed: no diary id given.';

    final repo = getIt<DiaryRepository>();
    final existing = await repo.getDiaryByBusinessId(id);
    if (existing == null) return 'Failed: no diary with id=$id.';

    final title = existing.title.trim().isEmpty
        ? 'Untitled'
        : existing.title.trim();
    if (!existing.show) {
      return '"$title" (id=$id) is already in the recycle bin.';
    }
    // 软删=移入回收站(show=false)；勿用 deleteADiary(那是永久删除+删媒体)。
    await repo.setVisibility(existing, show: false);
    return 'Moved "$title" (id=$id) to the recycle bin.';
  }

  static Future<String> _listCategories(Map<String, dynamic> input) async {
    final cats = await getIt<CategoryRepository>().getAllCategories();
    if (cats.isEmpty) return 'No categories yet.';
    final buffer = StringBuffer();
    for (final c in cats) {
      buffer.writeln('id=${c.id} name=${c.categoryName}');
    }
    return buffer.toString().trim();
  }

  static Future<String> _createCategory(Map<String, dynamic> input) =>
      runBatch(input, each: _createOneCategory);

  static Future<String> _createOneCategory(Map<String, dynamic> input) async {
    final name = (input['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return 'Failed: the category name cannot be empty.';
    final category = Category.create(categoryName: name);
    try {
      await getIt<CategoryRepository>().insertACategory(category);
      return 'Created category "$name", id=${category.id}.';
    } catch (_) {
      return 'Failed: could not create the category.';
    }
  }

  static Future<String> _updateCategory(Map<String, dynamic> input) =>
      runBatch(input, each: _updateOneCategory);

  static Future<String> _updateOneCategory(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    final name = (input['name'] as String?)?.trim() ?? '';
    if (id.isEmpty || name.isEmpty) {
      return 'Failed: category id and name are both required.';
    }

    final repo = getIt<CategoryRepository>();
    final existing = await repo.getCategoryById(id);
    if (existing == null) {
      return 'Failed: no category with id=$id.';
    }
    final updated = existing.copyWith(
      categoryName: name,
      lastModified: .timestamp(),
    );
    try {
      await repo.insertACategory(updated);
      return 'Renamed the category to "$name" (id=$id).';
    } catch (_) {
      return 'Failed: could not rename the category.';
    }
  }

  static Future<String> _deleteCategory(Map<String, dynamic> input) =>
      runBatch(input, each: _deleteOneCategory);

  static Future<String> _deleteOneCategory(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return 'Failed: no category id given.';
    bool ok;
    try {
      ok = await getIt<CategoryRepository>().deleteACategory(id);
    } catch (_) {
      ok = false;
    }
    return ok
        ? 'Deleted the category (id=$id).'
        : 'Failed: the category does not exist, or it still holds diaries — refile them first.';
  }

  static const _validMemorySources = {'user_said', 'user_asked'};

  static const _validMemoryCategories = {'preference', 'theme', 'goal', 'fact'};

  static Future<String> _recallMemory(Map<String, dynamic> input) async {
    final repo = getIt<MemoryRepository>();
    final query = ((input['query'] as String?) ?? '').trim();
    final limit = ((input['limit'] as num?)?.toInt() ?? _defaultRecallLimit)
        .clamp(1, _maxRecallLimit);
    final hits = query.isEmpty
        ? await repo.getRecent(limit)
        : await repo.search(query, limit: limit);
    if (hits.isEmpty) {
      final total = await repo.count();
      return total == 0
          ? 'No saved facts yet. Nothing was remembered about this user.'
          : '0 matches among $total saved facts. Say plainly that you do not '
                'have it rather than guessing.';
    }
    final buffer = StringBuffer();
    for (final m in hits) {
      buffer.writeln('id=${m.id} kind=${m.category} text=${m.text}');
    }
    return buffer.toString().trim();
  }

  static Future<String> _rememberFact(Map<String, dynamic> input) =>
      runBatch(input, each: _rememberOneFact);

  static Future<String> _rememberOneFact(Map<String, dynamic> input) async {
    final text = (input['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) return 'Failed: the fact cannot be empty.';
    final rawCat = (input['category'] as String?)?.trim() ?? 'fact';
    final category = _validMemoryCategories.contains(rawCat) ? rawCat : 'fact';
    final repo = getIt<MemoryRepository>();
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isNotEmpty) {
      final current = await repo.get(id);
      if (current == null) return 'Failed: no memory with id=$id.';
      await repo.put(
        current.copyWith(
          text: text,
          category: category,
          updatedAt: .timestamp(),
        ),
      );
      return 'Revised the memory (id=$id): $text.';
    }
    final existing = await repo.findDuplicate(category, text);
    if (existing != null) {
      await repo.touch(existing.id);
      return 'Already saved ($category): ${existing.text} (id=${existing.id}).';
    }
    final rawSource = (input['source'] as String?)?.trim();
    final entry = MemoryEntry.create(
      category: category,
      text: text,
      source: _validMemorySources.contains(rawSource) ? rawSource : 'user_said',
    );
    await repo.put(entry);
    return 'Remembered ($category): $text (id=${entry.id}).';
  }

  static Future<String> _runJavascript(Map<String, dynamic> input) async {
    final code = (input['code'] as String?)?.trim() ?? '';
    if (code.isEmpty) return 'Failed: no code given.';
    try {
      final outcome = await JsSandbox.run(code);
      final buffer = StringBuffer();
      buffer.writeln(
        outcome.value.isEmpty
            ? 'Result: (no value)'
            : 'Result: ${outcome.value}',
      );
      if (outcome.logs.isNotEmpty) {
        buffer
          ..writeln('Console:')
          ..writeln(outcome.logs.join('\n'));
      }
      if (outcome.truncated) {
        buffer.writeln('(output was truncated — print less)');
      }
      return buffer.toString().trim();
    } catch (e) {
      return 'Failed: $e';
    }
  }

  static String _summarizeJavascript(
    AssistantTool _,
    Map<String, dynamic> _,
    String output,
  ) {
    final line = output
        .split('\n')
        .firstWhere((e) => e.startsWith('Result: '), orElse: () => '');
    final value = line.replaceFirst('Result: ', '').trim();
    if (value.isEmpty || value == '(no value)') {
      return l10n.assistant.toolJsEmpty;
    }
    return value;
  }

  static Future<String> _forgetFact(Map<String, dynamic> input) =>
      runBatch(input, each: _forgetOneFact);

  static Future<String> _forgetOneFact(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return 'Failed: no memory id given.';
    final ok = await getIt<MemoryRepository>().delete(id);
    return ok
        ? 'Deleted the memory (id=$id).'
        : 'Failed: no memory with id=$id.';
  }

  static Future<String?> _resolveCategoryId(Object? raw) async {
    final id = (raw as String?)?.trim();
    if (id == null || id.isEmpty) return null;
    final cat = await getIt<CategoryRepository>().getCategoryById(id);
    return cat == null ? null : id;
  }

  static DiaryMood? _parseMood(Object? raw) =>
      raw is String ? DiaryMood.values.asNameMap()[raw] : null;

  static Future<String?> _categoryNameOf(String id) async {
    final cats = await getIt<CategoryRepository>().getAllCategories();
    for (final c in cats) {
      if (c.id == id) return c.categoryName;
    }
    return null;
  }

  static String? _trimToNull(Object? raw) {
    final s = (raw as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static int _parseLimit(Object? raw) {
    final n = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}'.trim());
    if (n == null) return _defaultQueryLimit;
    return n.clamp(1, _maxQueryLimit);
  }

  static DateTime? _parseDate(Object? raw) {
    final s = (raw as String?)?.trim();
    if (s == null || s.isEmpty) return null;
    final parsed = DateTime.tryParse(s);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static bool _inRange(DateTime time, DateTime? start, DateTime? endExclusive) {
    if (start != null && time.isBefore(start)) return false;
    if (endExclusive != null && !time.isBefore(endExclusive)) return false;
    return true;
  }

  static SearchSort _toSearchSort(String? name) => switch (name) {
    'newest' => SearchSort.timeDesc,
    'oldest' => SearchSort.timeAsc,
    _ => SearchSort.relevance,
  };

  static DiarySort _toDiarySort(String? name) => switch (name) {
    'oldest' => DiarySort.timeAsc,
    'modified' => DiarySort.lastModifiedDesc,
    _ => DiarySort.timeDesc,
  };

  static int Function(Diary, Diary) _diaryComparator(String? name) =>
      switch (name) {
        'oldest' => (a, b) => a.time.compareTo(b.time),
        'modified' => (a, b) => b.lastModified.compareTo(a.lastModified),
        _ => (a, b) => b.time.compareTo(a.time),
      };

  static Future<String> _emptyQueryMessage(
    List<String> keywords,
    String? categoryId,
    DateTime? start,
    DateTime? endExclusive,
  ) async {
    final categoryName = categoryId == null
        ? null
        : await _categoryNameOf(categoryId);
    final conds = <String>[
      if (keywords.isNotEmpty) 'keywords "${keywords.join(' ')}"',
      if (categoryName != null) 'category "$categoryName"',
      if (start != null) 'from ${TimeFormat.isoDate(start)}',
      if (endExclusive != null)
        'to ${TimeFormat.isoDate(endExclusive.subtract(const Duration(days: 1)))}',
    ];
    return conds.isEmpty
        ? 'No diaries yet.'
        : 'No diaries match ${conds.join(', ')}.';
  }
}
