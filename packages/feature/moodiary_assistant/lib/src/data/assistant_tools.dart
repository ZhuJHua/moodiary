import 'dart:convert';

import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

typedef AssistantToolRun = Future<String> Function(Map<String, dynamic> input);

/// 工具结果的失败前缀。**是个约定**：结果给模型看是英文，而界面上那一行要 i18n，
/// 成败得有个不依赖语言的判据。
const String _failurePrefix = 'Failed:';

/// 把一次调用压成一行摘要，显示在对话里那条提示条上。
///
/// **由工具自己实现**：截断结果字符串得到的是「id=0198a… 【2026-08-11】…」这种
/// 半截元数据，而工具自己知道该说「7 条 · 08-11 至 08-17」。
typedef AssistantToolSummarize =
    String Function(AssistantTool tool, Map<String, dynamic> input, String output);

class AssistantToolSpec {
  final AssistantTool tool;
  final String description;
  final Map<String, dynamic> jsonSchema;
  final AssistantToolRun run;

  /// 缺省时回落到结果的首行。
  final AssistantToolSummarize? summarize;

  const AssistantToolSpec({
    required this.tool,
    required this.description,
    required this.jsonSchema,
    required this.run,
    this.summarize,
  });

  /// 这次调用显示成一行是什么样。
  /// 这次调用显示成一行是什么样。**走 i18n，与给模型的英文结果无关** ——
  /// 早先是截结果首行，结果英文化之后那条路会让用户看到英文。
  String summaryOf(Map<String, dynamic> input, String output) {
    if (output.startsWith(_failurePrefix)) return l10n.assistant.toolFailed;
    final custom = summarize?.call(tool, input, output);
    if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    return l10n.assistant.toolDone;
  }

  String get id => tool.id;
}

abstract final class AssistantToolRegistry {
  static const _defaultQueryLimit = 8;

  static const _maxQueryLimit = 20;

  static const _maxExcerptLength = 200;

  static const _maxFullContentLength = 4000;

  /// getDiary 一次最多读几篇。再多就该先用 queryDiaries 收窄。
  static const _maxBatchRead = 10;

  /// 工具定义**一律英文**：读者是模型，不是用户。跨模型的指令服从度在英文上更稳，
  /// 同样的意思也更省 token（这些描述每一轮都要重发）。
  ///
  /// 结果字符串同理 —— 但结果里夹带的用户数据（标题、正文、分类名）原样保留。
  /// 给用户看的那一行由 [AssistantToolSpec.summarize] 单独产出，走 i18n。
  static const List<AssistantToolSpec> specs = [
    AssistantToolSpec(
      tool: .queryDiaries,
      description:
          'Search or browse the diaries stored on this device. Every argument is '
          'an optional filter; with keywords it ranks by relevance, without them '
          'it browses by date and/or category. '
          'Results carry id, date, mood and a short excerpt — not the full text '
          '(use getDiary for that) — and state the total number of matches, which '
          'may exceed what is returned. Never present the returned rows as the '
          'complete set when the total says otherwise. '
          'Mood is 0.00 (low) to 1.00 (high); 0.50 is also the default for entries '
          'whose mood was never set, so do not read emotion into it on its own. '
          'Call this whenever the user asks about what they wrote, or to locate an '
          'entry before editing or deleting it.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'keywords': {
            'type': 'string',
            'description':
                'Space-separated search terms. Omit to browse by the filters below.',
          },
          'categoryId': {
            'type': 'string',
            'description': 'Restrict to one category (id from listCategories).',
          },
          'startDate': {
            'type': 'string',
            'description': 'Inclusive start, YYYY-MM-DD in the user local time.',
          },
          'endDate': {
            'type': 'string',
            'description': 'Inclusive end, YYYY-MM-DD in the user local time.',
          },
          'sort': {
            'type': 'string',
            'enum': ['newest', 'oldest', 'modified', 'relevance'],
            'description':
                'Defaults to newest. relevance applies only with keywords.',
          },
          'limit': {
            'type': 'integer',
            'description': 'How many entries to return. Default 8, max 20.',
            'minimum': 1,
            'maximum': 20,
          },
        },
      },
      run: _queryDiaries,
      summarize: _summarizeQuery,
    ),
    AssistantToolSpec(
      tool: .getDiary,
      description:
          'Read the full text of diaries by id (queryDiaries returns excerpts only). '
          'Pass every id you need in one call — never call this once per entry. '
          'Max 10 per call.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'ids': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Diary ids from queryDiaries. Max 10.',
          },
        },
        'required': ['ids'],
      },
      run: _getDiary,
      summarize: _summarizeGet,
    ),
    AssistantToolSpec(
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
          'Save content as a new diary. Call this when the user asks you to write '
          'one down or to keep something as an entry. The body is Markdown.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': 'Optional title.'},
          'content': {'type': 'string', 'description': 'Body, Markdown.'},
          'mood': {
            'type': 'number',
            'description':
                '0.00 (low) to 1.00 (high). Omit unless the user conveyed a mood.',
            'minimum': 0,
            'maximum': 1,
          },
          'categoryId': {
            'type': 'string',
            'description': 'Optional category id from listCategories.',
          },
        },
        'required': ['content'],
      },
      run: _createDiary,
      summarize: _summarizeWrite,
    ),
    AssistantToolSpec(
      tool: .updateDiary,
      description:
          'Edit one diary by id. Only the fields you pass change; the rest are left '
          'alone. Get the id from queryDiaries first.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Diary id from queryDiaries.'},
          'title': {'type': 'string', 'description': 'New title.'},
          'content': {'type': 'string', 'description': 'New body, Markdown.'},
          'mood': {
            'type': 'number',
            'description': 'New mood, 0.00 to 1.00.',
            'minimum': 0,
            'maximum': 1,
          },
          'categoryId': {'type': 'string', 'description': 'New category id.'},
        },
        'required': ['id'],
      },
      run: _updateDiary,
      summarize: _summarizeWrite,
    ),
    AssistantToolSpec(
      tool: .deleteDiary,
      description:
          'Move a diary to the recycle bin by id, where the user can restore it. '
          'Get the id from queryDiaries first.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Diary id from queryDiaries.'},
        },
        'required': ['id'],
      },
      run: _deleteDiary,
      summarize: _summarizeWrite,
    ),
    AssistantToolSpec(
      tool: .listCategories,
      description:
          'List every diary category with its id. Call this to get an id before '
          'filing, renaming or deleting a category.',
      jsonSchema: {'type': 'object', 'properties': {}},
      run: _listCategories,
      summarize: _summarizeList,
    ),
    AssistantToolSpec(
      tool: .createCategory,
      description: 'Add a diary category.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Category name.'},
        },
        'required': ['name'],
      },
      run: _createCategory,
      summarize: _summarizeWrite,
    ),
    AssistantToolSpec(
      tool: .updateCategory,
      description: 'Rename a category by id (from listCategories).',
      jsonSchema: {
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
      run: _updateCategory,
      summarize: _summarizeWrite,
    ),
    AssistantToolSpec(
      tool: .deleteCategory,
      description:
          'Delete a category by id. Only succeeds while it holds no diaries — '
          'move or refile them first.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'Category id from listCategories.',
          },
        },
        'required': ['id'],
      },
      run: _deleteCategory,
      summarize: _summarizeWrite,
    ),
    AssistantToolSpec(
      tool: .listMemories,
      description:
          'List the long-term facts you saved about the user, each with its id. '
          'The facts themselves are already given to you every turn — call this '
          'only when you need an id to revise or forget one.',
      jsonSchema: {'type': 'object', 'properties': {}},
      run: _listMemories,
      summarize: _summarizeList,
    ),
    AssistantToolSpec(
      tool: .rememberFact,
      description:
          'Save one durable fact about the user — a lasting preference, a recurring '
          'theme, an ongoing goal. Not passing details, not one-off events, and '
          'never anything they asked you to keep private.',
      jsonSchema: {
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
        },
        'required': ['category', 'text'],
      },
      run: _rememberFact,
      summarize: _summarizeWrite,
    ),
    AssistantToolSpec(
      tool: .updateMemory,
      description: 'Revise a saved fact by id (from listMemories).',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Memory id from listMemories.'},
          'text': {'type': 'string', 'description': 'The revised fact.'},
          'category': {
            'type': 'string',
            'enum': ['preference', 'theme', 'goal', 'fact'],
            'description': 'New kind, if it changed.',
          },
        },
        'required': ['id', 'text'],
      },
      run: _updateMemory,
      summarize: _summarizeWrite,
    ),
    AssistantToolSpec(
      tool: .forgetFact,
      description:
          'Delete a saved fact by id (from listMemories). This is permanent.',
      jsonSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Memory id from listMemories.'},
        },
        'required': ['id'],
      },
      run: _forgetFact,
      summarize: _summarizeWrite,
    ),
  ];

  /// 把一轮用过的工具压成一段记录，回灌进发给模型的历史。
  ///
  /// **回灌摘要不是完整结果。** 完整结果在当轮已经进过模型的上下文、答案正文就是
  /// 从它写出来的；跨轮真正丢掉的只是「我已经查过了」这件事，摘要足够表达。逐轮
  /// 重放完整结果的话，一次 queryDiaries 的两千字会在之后每一轮里再付一遍。
  ///
  /// 入参一并带上：模型据此能判断「这次的问题和上次查的是不是同一个范围」，
  /// 要重查也知道该传什么。返回空串表示这一轮没有已完成的工具调用。
  static String recordOf(List<AssistantToolCall> calls) {
    final lines = <String>[];
    for (final call in calls) {
      if (!call.done) continue;
      final spec = byId(call.name);
      final args = call.argsJson.isEmpty ? '{}' : call.argsJson;
      final summary = spec == null
          ? ''
          : spec.summaryOf(_decodeArgs(call.argsJson), call.result);
      lines.add(
        '- ${call.name}($args)${summary.isEmpty ? '' : ' → $summary'}',
      );
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

  /// 查询的一行摘要：命中数 + 实际生效的筛选条件。
  ///
  /// 不从结果文本里截 —— 那开头是「共命中 47 篇，以下是前 8 篇…」，
  /// 而提示条要的是「47 篇 · 08-11 至 08-17」这种能一眼扫过去的形状。
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
      ?_trimToNull(input['keywords']),
      if (_trimToNull(input['startDate']) case final a?)
        _trimToNull(input['endDate']) == null ? a : '$a – ${input['endDate']}',
    ];
    return parts.join(' · ');
  }

  static String _summarizeGet(
    AssistantTool _,
    Map<String, dynamic> input,
    String _,
  ) => l10n.assistant.toolRead(
    count: _parseIds(input['ids'] ?? input['id']).length,
  );

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
    // 结果是「首行说明 + 每项一行」，减掉首行就是项数。
    final lines = output.split('\n').where((e) => e.startsWith('- ')).length;
    return l10n.assistant.toolListed(count: lines);
  }

  /// 写入类共用。摘要说的是**动了什么**，不是「已创建」—— 提示条前面那个类型词
  /// （「创建日记」）已经说过动作了，再说一遍是废话。
  /// 写入类共用。摘要说的是**动了什么**，不是「已创建」—— 提示条前面那个类型词
  /// （「创建日记」）已经说过动作了，再说一遍是废话。
  ///
  /// 这里刻意逐处写全 `l10n.assistant.xxx`，不存局部别名：slang 的死键扫描是按
  /// `l10n.` 前缀做子串匹配的，起个别名它就看不见，这几个键会被误报成未使用。
  static String _summarizeWrite(
    AssistantTool tool,
    Map<String, dynamic> input,
    String output,
  ) {
    return switch (tool) {
      .createDiary =>
        _trimToNull(input['title']) ?? l10n.assistant.toolUntitled,
      .createCategory || .updateCategory =>
        _trimToNull(input['name']) ?? l10n.assistant.toolDone,
      .rememberFact || .updateMemory =>
        _trimToNull(input['text']) ?? l10n.assistant.toolDone,
      .deleteDiary => l10n.assistant.toolTrashed,
      .deleteCategory || .forgetFact => l10n.assistant.toolDeleted,
      _ => l10n.assistant.toolUpdated,
    };
  }

  static Future<String> _queryDiaries(Map<String, dynamic> input) async {
    final rawKeywords = ((input['keywords'] as String?) ?? '').trim();
    final keywordsForDisplay = rawKeywords
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final categoryId = _trimToNull(input['categoryId']);
    final sortName = (input['sort'] as String?)?.trim();
    final limit = _parseLimit(input['limit']);
    // 起止日期按本地日历解释；结束日以次日零点作排他上界，从而包含整个结束日。
    final start = _parseDate(input['startDate']);
    final endExclusive = _parseDate(input['endDate'])
        ?.add(const Duration(days: 1));

    final repo = DiaryRepository.get();
    List<Diary> results;
    if (rawKeywords.isNotEmpty) {
      // 关键词必须走与建索引同一套 jieba 分词，否则中文按空格硬切、命中率骤降。
      final tokenized = await Tokenizer.tokenize(text: rawKeywords);
      results = await repo.searchDiaries(
        cutTokens: tokenized.cut,
        cutForSearchTokens: tokenized.cutForSearch,
        categoryId: categoryId,
        start: start,
        end: endExclusive,
        sort: _toSearchSort(sortName),
      );
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

    if (results.isEmpty) {
      return await _emptyQueryMessage(
        keywordsForDisplay,
        categoryId,
        start,
        endExclusive,
      );
    }
    // **总数必须回传**：只给前 limit 条而不说还有多少，模型会把这几条当成全部，
    // 然后对用户说「你这周只写了 8 篇」——一个由工具输出直接导致的错误结论。
    return _formatDiaryList(results.take(limit), total: results.length);
  }

  /// 批量读全文。**一次多篇**：总结一周日记要 7 篇，逐篇调用就是 7 轮往返，
  /// 而每一轮都要把整段历史重发一遍。
  static Future<String> _getDiary(Map<String, dynamic> input) async {
    final ids = _parseIds(input['ids'] ?? input['id']);
    if (ids.isEmpty) {
      return 'Failed: no diary id given. Get ids from queryDiaries first.';
    }

    final repo = DiaryRepository.get();
    final chunks = <String>[];
    final missing = <String>[];
    for (final id in ids.take(_maxBatchRead)) {
      final diary = await repo.getDiaryByBusinessId(id);
      // 排除回收站
      if (diary == null || !diary.show) {
        missing.add(id);
        continue;
      }
      chunks.add(_formatDiaryFull(diary));
    }

    final buffer = StringBuffer();
    if (missing.isNotEmpty) {
      buffer.writeln(
        'Not found (deleted, or the id is wrong — recheck with queryDiaries): '
        '${missing.join(', ')}',
      );
      if (chunks.isNotEmpty) buffer.writeln();
    }
    if (ids.length > _maxBatchRead) {
      buffer.writeln('(Only the first $_maxBatchRead were read; call again for the rest.)');
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
      ..writeln('mood=${diary.mood.toStringAsFixed(2)}');
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

  /// 兼容单个 id 与 id 数组两种传法 —— 模型偶尔会退回旧形状。
  static List<String> _parseIds(Object? raw) {
    final out = <String>{};
    if (raw is String) {
      final t = raw.trim();
      if (t.isNotEmpty) out.add(t);
    } else if (raw is List) {
      for (final e in raw) {
        final t = '$e'.trim();
        if (t.isNotEmpty) out.add(t);
      }
    }
    return out.toList();
  }

  static Future<String> _diaryOverview(Map<String, dynamic> input) async {
    final repo = DiaryRepository.get();
    final counts = await repo.diaryCountByCategory();
    if (counts.total == 0) return 'No diaries yet.';

    final cats = (await CategoryRepository.get().getAllCategories().run())
        .getOrElse((_) => const <Category>[]);
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

    // 心情分布：这是日记 App 的助手最常被问到的东西，概览里没有它，模型只能
    // 去逐篇拉全文自己数 —— 那既慢又容易在 limit 上出错。
    final moods = await repo.getDiaryByCategory(sort: .timeDesc, limit: 9999);
    final rated = [
      for (final d in moods)
        if (d.mood != 0.5) d.mood,
    ];
    if (rated.isNotEmpty) {
      final avg = rated.reduce((a, b) => a + b) / rated.length;
      final low = rated.where((m) => m < 0.4).length;
      final high = rated.where((m) => m > 0.6).length;
      buffer
        ..writeln('mood (0.00 low ~ 1.00 high; '
            '${moods.length - rated.length} entries with no mood set are excluded):')
        ..writeln('- mean=${avg.toStringAsFixed(2)}')
        ..writeln('- low(<0.40)=$low, high(>0.60)=$high, '
            'middle=${rated.length - low - high}');
    }
    return buffer.toString().trim();
  }

  static Future<String> _createDiary(Map<String, dynamic> input) async {
    final title = (input['title'] as String?)?.trim() ?? '';
    final content = (input['content'] as String?)?.trim() ?? '';
    if (content.isEmpty) return 'Failed: the body cannot be empty.';

    final mood = _parseMood(input['mood']) ?? 0.5;
    final categoryId = await _resolveCategoryId(input['categoryId']);

    final converted = _toTiptap(content);
    final diary = Diary.create(
      categoryId: categoryId,
      title: title,
      content: converted.content,
      contentText: converted.contentText,
      mood: mood,
      weather: const [],
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: const [],
      position: const [],
      type: converted.type,
      aspect: null,
    );
    await DiaryRepository.get().insertADiary(diary);
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

  static Future<String> _updateDiary(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return 'Failed: no diary id given.';

    final repo = DiaryRepository.get();
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
      // 内容变更必须重算媒体引用列表，否则媒体库出现幻影条目、废弃媒体永不回收。
      final media = DiaryContent.of(updated).media;
      updated = updated.copyWith(
        imageName: media.images,
        videoName: media.videos,
        audioName: media.audios,
      );
    }
    final mood = _parseMood(input['mood']);
    if (mood != null) updated = updated.copyWith(mood: mood);
    if (input.containsKey('categoryId')) {
      final rawCategory = (input['categoryId'] as String?)?.trim() ?? '';
      if (rawCategory.isEmpty) {
        updated = updated.copyWith(categoryId: null); // 显式清除归类
      } else {
        final resolved = await _resolveCategoryId(rawCategory);
        // 传了非空但无效的 id 时报错、保持原归类不变，避免「无效 id 静默清空分类」。
        if (resolved == null) {
          return 'Failed: no category with id=$rawCategory (check listCategories).';
        }
        updated = updated.copyWith(categoryId: resolved);
      }
    }
    updated = updated.copyWith(lastModified: .timestamp());

    await repo.updateADiary(newDiary: updated);
    final shown = updated.title.trim().isEmpty ? 'Untitled' : updated.title.trim();
    return 'Updated "$shown" (id=$id).';
  }

  static Future<String> _deleteDiary(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return 'Failed: no diary id given.';

    final repo = DiaryRepository.get();
    final existing = await repo.getDiaryByBusinessId(id);
    if (existing == null) {
      return 'Failed: no diary with id=$id.';
    }
    final title = existing.title.trim().isEmpty
        ? 'Untitled'
        : existing.title.trim();
    if (!existing.show) {
      return '"$title" (id=$id) is already in the recycle bin.';
    }
    // 软删=移入回收站(show=false)；勿用 deleteADiary(那是永久删除+删媒体)。
    await repo.updateADiary(
      newDiary: existing.copyWith(show: false, lastModified: .timestamp()),
    );
    return 'Moved "$title" (id=$id) to the recycle bin.';
  }

  static Future<String> _listCategories(Map<String, dynamic> input) async {
    final cats = (await CategoryRepository.get().getAllCategories().run())
        .getOrElse((_) => const <Category>[]);
    if (cats.isEmpty) return 'No categories yet.';
    final buffer = StringBuffer();
    for (final c in cats) {
      buffer.writeln('id=${c.id} name=${c.categoryName}');
    }
    return buffer.toString().trim();
  }

  static Future<String> _createCategory(Map<String, dynamic> input) async {
    final name = (input['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return 'Failed: the category name cannot be empty.';
    final category = Category.create(categoryName: name);
    final ok = (await CategoryRepository.get().insertACategory(category).run())
        .isRight();
    return ok ? 'Created category "$name", id=${category.id}.' : 'Failed: could not create the category.';
  }

  static Future<String> _updateCategory(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    final name = (input['name'] as String?)?.trim() ?? '';
    if (id.isEmpty || name.isEmpty) return 'Failed: category id and name are both required.';

    final repo = CategoryRepository.get();
    final existing = await repo.getCategoryById(id);
    if (existing == null) {
      return 'Failed: no category with id=$id.';
    }
    final updated = existing.copyWith(
      categoryName: name,
      lastModified: .timestamp(),
    );
    final ok = (await repo.insertACategory(updated).run()).isRight();
    return ok ? 'Renamed the category to "$name" (id=$id).' : 'Failed: could not rename the category.';
  }

  static Future<String> _deleteCategory(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return 'Failed: no category id given.';
    final ok = (await CategoryRepository.get().deleteACategory(id).run())
        .getOrElse((_) => false);
    return ok
        ? 'Deleted the category (id=$id).'
        : 'Failed: the category does not exist, or it still holds diaries — refile them first.';
  }

  static const _validMemoryCategories = {'preference', 'theme', 'goal', 'fact'};

  static Future<String> _listMemories(Map<String, dynamic> input) async {
    final memories = await MemoryRepository.get().getAll();
    if (memories.isEmpty) return 'No saved facts yet.';
    final buffer = StringBuffer();
    for (final m in memories) {
      buffer.writeln('id=${m.id} kind=${m.category} text=${m.text}');
    }
    return buffer.toString().trim();
  }

  static Future<String> _rememberFact(Map<String, dynamic> input) async {
    final text = (input['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) return 'Failed: the fact cannot be empty.';
    final rawCat = (input['category'] as String?)?.trim() ?? 'fact';
    final category = _validMemoryCategories.contains(rawCat) ? rawCat : 'fact';
    final entry = MemoryEntry.create(category: category, text: text);
    await MemoryRepository.get().put(entry);
    return 'Remembered ($category): $text (id=${entry.id}).';
  }

  static Future<String> _updateMemory(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    final text = (input['text'] as String?)?.trim() ?? '';
    if (id.isEmpty || text.isEmpty) return 'Failed: memory id and text are both required.';
    final repo = MemoryRepository.get();
    final existing = await repo.get(id);
    if (existing == null) return 'Failed: no memory with id=$id.';
    final rawCat = (input['category'] as String?)?.trim();
    final category = (rawCat != null && _validMemoryCategories.contains(rawCat))
        ? rawCat
        : existing.category;
    await repo.put(
      existing.copyWith(
        text: text,
        category: category,
        updatedAt: .timestamp(),
      ),
    );
    return 'Updated the memory (id=$id): $text.';
  }

  static Future<String> _forgetFact(Map<String, dynamic> input) async {
    final id = (input['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return 'Failed: no memory id given.';
    final ok = await MemoryRepository.get().delete(id);
    return ok ? 'Deleted the memory (id=$id).' : 'Failed: no memory with id=$id.';
  }

  static Future<String?> _resolveCategoryId(Object? raw) async {
    final id = (raw as String?)?.trim();
    if (id == null || id.isEmpty) return null;
    final cat = await CategoryRepository.get().getCategoryById(id);
    return cat == null ? null : id;
  }

  static double? _parseMood(Object? raw) =>
      raw is num ? raw.toDouble().clamp(0.0, 1.0).toDouble() : null;

  /// 分类 id → 名字。查不到（已删）时返回 null，调用方自行降级。
  static Future<String?> _categoryNameOf(String id) async {
    final cats = (await CategoryRepository.get().getAllCategories().run())
        .getOrElse((_) => const <Category>[]);
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

  /// 解析 `YYYY-MM-DD` 为本地日历日的零点。无法解析返回 null。
  static DateTime? _parseDate(Object? raw) {
    final s = (raw as String?)?.trim();
    if (s == null || s.isEmpty) return null;
    final parsed = DateTime.tryParse(s);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// [start] 含、[endExclusive] 排他，按绝对时刻比较（`time` 为 UTC，本地边界仍按瞬时可比）。
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

  static String _formatDiaryList(Iterable<Diary> diaries, {required int total}) {
    final shown = diaries.length;
    final buffer = StringBuffer();
    buffer.writeln(
      shown < total
          ? '$total matches; the first $shown follow. Raise limit or narrow the '
                'filters for more.'
          : '$total matches:',
    );
    for (final diary in diaries) {
      final title = diary.title.trim().isEmpty ? 'Untitled' : diary.title.trim();
      final cat = diary.categoryId;
      final catPart = (cat != null && cat.isNotEmpty) ? ' categoryId=$cat' : '';
      buffer.writeln(
        'id=${diary.id} 【${TimeFormat.isoDate(diary.time)}】$title '
        'mood=${diary.mood.toStringAsFixed(2)}$catPart',
      );
      final text = diary.contentText.trim();
      if (text.isNotEmpty) {
        buffer.writeln(
          text.length > _maxExcerptLength
              // 明写「摘录」而不是只加个省略号：模型分不清「日记就这么短」和
              // 「被我们截断了」，据此下结论就是编造。要全文请调 getDiary。
              ? '${text.substring(0, _maxExcerptLength)}… (excerpt; full text via getDiary)'
              : text,
        );
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  static Future<String> _emptyQueryMessage(
    List<String> keywords,
    String? categoryId,
    DateTime? start,
    DateTime? endExclusive,
  ) async {
    // 吐 uuid 没用：模型没法在回复里跟用户说「分类 0198a…下没有日记」。
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
