/// Diary read and write tools: list, read, create, update, delete, search, tags
/// and the link graph of one diary.
library;

import 'package:flutter/foundation.dart' show internal;
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../media/diary_media.dart';
import '../ops/diary_display.dart';
import '../ops/diary_queries.dart';
import '../ops/diary_writes.dart';
import 'arguments.dart';
import 'batch.dart';
import 'diary_payloads.dart';
import 'diary_queries.dart';
import 'diary_references.dart';
import 'diary_write_lock.dart';
import 'output_schemas.dart';
import 'schemas.dart';
import 'tool_def.dart';

@internal
final List<ToolDefinition> diaryTools = [
  ToolDef(
    name: 'get_diary',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('get_diary', result.data),
    title: 'Read diaries',
    description: (surface) =>
        'Read diary bodies and metadata by ids (max 10). Pass every id you '
        'need in one call, using ids from search_diaries. Unknown or recycled '
        'ids are reported in missing. Markdown preserves media as ![name](src); '
        'keep these references when rewriting content. '
        '${surface == ToolSurface.assistant ? 'Bodies are Markdown, capped at 4000 characters; truncated and fullLength report any cap. Never rewrite from a truncated body.' : 'contentFormat selects markdown (default), text or the raw Tiptap document JSON. document is subject to the $mcpResultChars character result limit. linkStyle=uri preserves diary mention targets; label keeps only labels. includeLinks=false omits the graph. Attach files with add_diary_image or add_diary_attachment and inspect them with list_diary_media.'}',
    input: (surface) => Schema.fromMap({
      'type': 'object',
      'properties': {
        'ids': toolIdsSchema(diaryIdSchema, max: maxBatchRead),
        if (surface == ToolSurface.mcp) ...{
          'contentFormat': readContentFormatSchema,
          'linkStyle': linkStyleSchema,
          'includeLinks': {
            'type': 'boolean',
            'default': true,
            'description':
                'false omits links, the graph of forward links, backlinks and '
                'dangling diary ids of this diary.',
          },
        },
      },
      'additionalProperties': false,
      'required': ['ids'],
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: toolOutputSchema('get_diary'),
    parse: _parseGetDiary,
    run: (input, ctx) => _getDiaries(
      input,
      ctx,
      diaries: ctx.diaries,
      categories: ctx.categories,
    ),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'create_diary',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('create_diary', result.data),
    title: 'Create a diary',
    description: (_) =>
        'Pass every item in one call. Each result has ok and an error on failure; '
        'do not repeat items that already succeeded. '
        'Save content as new diaries in items (1–20) and return their summaries. '
        'Call this when the user asks you to write something down or keep an entry. '
        'content is required; '
        'contentFormat=markdown (default) parses it as Markdown and stores '
        'the editor document so headings, lists and emphasis survive, text '
        'stores literal paragraphs so Markdown syntax stays visible, and '
        'document expects a Tiptap document JSON object and refuses anything '
        'else with invalid params. The new diary is visible (the summary '
        'reports it as show); title may be empty. The body may not reference '
        'media: a body with media nodes is invalid params, because media has '
        'to be added to an existing diary with add_diary_image or '
        'add_diary_attachment (which also creates its media index row).',
    input: (_) => batchItemsSchema({
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'description': 'Diary title; may be empty.',
        },
        'content': {
          'type': 'string',
          'description':
              'Diary body; required. Interpreted according to contentFormat.',
        },
        'contentFormat': writeContentFormatSchema,
        'time': diaryTimeSchema,
        'categoryId': categoryIdSchema,
        'mood': moodSchema,
        'tags': tagsSchema,
      },
      'required': ['content'],
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.write,
    idempotent: false,
    output: toolOutputSchema('create_diary'),
    parse: toolBatchItems,
    run: (items, ctx) => runToolBatch(
      items,
      (item) => _createDiary(
        _parseCreateDiary(item),
        diaries: ctx.diaries,
        categories: ctx.categories,
      ),
    ),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'update_diary',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('update_diary', result.data),
    title: 'Update a diary',
    description: (_) =>
        'Pass every item in one call. Each result has ok and an error on failure; '
        'do not repeat items that already succeeded. '
        'Updates the given fields of each diary in the batch and leaves every omitted field '
        'unchanged; lastModified is bumped. Send null to clear a nullable '
        'field: categoryId, mood and tags (null or an empty array); '
        'title is cleared with an empty string. content and time are '
        'not nullable, so an explicit null for them is ignored. content '
        'replaces the whole body and contentFormat selects how it is '
        'interpreted (markdown default, text, or document for a Tiptap '
        'document JSON object). Media nodes in the body may only reference '
        'files this diary already owns (add new files with add_diary_image '
        'or add_diary_attachment); another diary\'s media name is invalid '
        'params. Recycled diaries are not found. An unknown category id is '
        'an item error; an unknown diary id also fails only that item.',
    input: (_) => batchItemsSchema({
      'type': 'object',
      'properties': {
        'id': diaryIdSchema,
        'title': {
          'type': 'string',
          'description': 'New title; an empty string clears it.',
        },
        'content': {
          'type': 'string',
          'description':
              'New body; replaces the old one. Interpreted according to '
              'contentFormat.',
        },
        'contentFormat': writeContentFormatSchema,
        'time': diaryTimeSchema,
        'categoryId': categoryIdSchema,
        'mood': moodSchema,
        'tags': tagsSchema,
      },
      'required': ['id'],
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.write,
    idempotent: true,
    output: toolOutputSchema('update_diary'),
    parse: toolBatchItems,
    run: (items, ctx) => runToolBatch(
      items,
      (item) => _updateDiary(
        _parseUpdateDiary(item),
        diaries: ctx.diaries,
        categories: ctx.categories,
      ),
    ),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'delete_diary',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('delete_diary', result.data),
    title: 'Delete a diary',
    description: (_) =>
        'Pass every item in one call. Each result has ok and an error on failure; '
        'do not repeat items that already succeeded. '
        'Moves each diary in the batch to the recycle bin (show=false). This can be undone '
        'in the app. Permanent deletion is only available in the app. title '
        'is the stored title, empty when the diary had none. An unknown id '
        'fails only that item.',
    input: (_) => Schema.fromMap({
      'type': 'object',
      'properties': {'ids': toolIdsSchema(diaryIdSchema)},
      'required': ['ids'],
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.write,
    idempotent: true,
    output: toolOutputSchema('delete_diary'),
    parse: toolBatchIds,
    run: (items, ctx) => runToolBatch(
      items,
      (item) => _deleteDiary(
        _parseDeleteDiary(item),
        diaries: ctx.diaries,
        categories: ctx.categories,
      ),
    ),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'search_diaries',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('search_diaries', result.data),
    title: 'Search diaries',
    description: (surface) =>
        'Search or browse visible diaries. Omit query to browse by date, category '
        'or exact tag. Keyword terms combine with AND; prefer one or two specific '
        'words. Chinese text, pinyin and Latin text match. Results contain ids, '
        'titles, times, moods, categories, tags and excerpts; use get_diary for '
        'the full Markdown body before editing. Page with limit and offset. '
        'If total exceeds returned rows or totalIsLowerBound is true, say so '
        'instead of presenting the rows as the complete set. '
        '${surface == ToolSurface.assistant ? 'mode=auto fuses keyword and local semantic search when enabled; keyword and meaning force a path. Each hit reports via and similarity.' : 'Search is keyword-only.'} '
        'Mood is awful, bad, okay, good or great; null means not recorded.',
    input: (surface) => Schema.fromMap({
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'Keywords or a sentence; omit to browse.',
        },
        if (surface == ToolSurface.assistant)
          'mode': {'type': 'string', 'enum': diarySearchModeValues},
        'tag': {'type': 'string'},
        'categoryId': categoryIdSchema,
        'startDate': startDateSchema,
        'endDate': endDateSchema,
        'sort': diarySearchSortSchema,
        'limit': limitSchema,
        'offset': offsetSchema,
        'excerpt': excerptSchema,
      },
      'additionalProperties': false,
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: toolOutputSchema('search_diaries'),
    parse: _parseSearchDiaries,
    run: (input, ctx) => _searchDiaries(
      ctx,
      input,
      diaries: ctx.diaries,
      categories: ctx.categories,
    ),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'get_diary_links',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('get_diary_links', result.data),
    title: 'Read diary links',
    description: (_) =>
        'Lists the diaries this diary links to (forward), the diaries that '
        'link to it (backlinks) and the ids it mentions that do not exist '
        '(dangling), each with id, title and time. A dangling id is a '
        'moodiary://diary/<id> link to a diary that was deleted or never '
        'synced to this device.',
    input: (_) => Schema.fromMap({
      'type': 'object',
      'properties': {'id': diaryIdSchema},
      'required': ['id'],
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: toolOutputSchema('get_diary_links'),
    parse: _parseGetDiaryLinks,
    run: (input, ctx) => _getDiaryLinks(input, diaries: ctx.diaries),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'list_tags',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('list_tags', result.data),
    title: 'List tags',
    description: (_) =>
        'Lists the tags used by visible diaries with their usage counts, '
        'most used first. The database has no tag index, so this aggregates '
        'over every visible diary and is linear in the number of diaries.',
    input: (_) => Schema.fromMap({
      'type': 'object',
      'properties': {'limit': tagLimitSchema},
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: toolOutputSchema('list_tags'),
    parse: _parseListTags,
    run: (input, ctx) => _listTags(input, diaries: ctx.diaries),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
];

/// Rejects unknown category filters instead of returning an empty page.
Future<String?> _categoryFilter(
  String? id,
  String subject,
  CategoryRepository categories,
) async {
  if (id == null) return null;
  if (await categories.getCategoryById(id) == null) {
    throw ToolArgumentException(
      '$subject: categoryId "$id" is not a known category; call '
      'list_categories first',
    );
  }
  return id;
}

typedef _PageArgs = ({
  String? categoryId,
  DateTime? start,
  DateTime? end,
  int limit,
  int offset,
});

_PageArgs _pageArgs(ToolArguments args) {
  final categoryId = args.optionalText('categoryId');
  final start = args.optionalDate('startDate');
  final end = args.optionalDate('endDate', endOfDay: true);
  args.requireOrderedRange(start, end);
  return (
    categoryId: categoryId,
    start: start,
    end: end,
    limit: args.optionalInt('limit', fallback: 20, min: 1, max: 100),
    offset: args.optionalInt('offset', fallback: 0, min: 0, max: 1000000),
  );
}

Map<String, dynamic> _summary(
  Diary diary, {
  String? categoryName,
  required String excerpt,
}) {
  final summary = diarySummary(
    diary,
    categoryName: categoryName,
    renderMarkdown: excerpt == 'markdown',
    includeExcerpt: excerpt != 'none',
  );
  return summary;
}

Future<ToolResult> _mutation(
  CategoryRepository categories,
  Diary diary, {
  required bool created,
}) async {
  final names = await categoryNames(categories);
  return ToolResult({
    if (created) 'created': true else 'updated': true,
    'diary': _summary(
      diary,
      categoryName: names[diary.categoryId],
      excerpt: 'plain',
    ),
  });
}

DiaryContentFormat _writeFormat(String? value) => switch (value) {
  'text' => DiaryContentFormat.plainText,
  'document' => DiaryContentFormat.document,
  _ => DiaryContentFormat.markdown,
};

ToolResult _writeFailure(String subject, DiaryOpsException e, String id) =>
    switch (e.failure) {
      DiaryOpsFailure.invalidCategory => throw ToolArgumentException(
        '$subject: categoryId "${e.categoryId}" is not a known category; call '
        'list_categories first',
      ),
      DiaryOpsFailure.invalidDocument => throw ToolArgumentException(
        '$subject: content is not a Tiptap document; contentFormat="document" '
        'expects a JSON object with type "doc"',
      ),
      DiaryOpsFailure.emptyContent => throw ToolArgumentException(
        '$subject: content must not be empty',
      ),
      DiaryOpsFailure.notFound => _failure('$subject: no diary with id="$id".'),
      DiaryOpsFailure.foreignMedia => throw ToolArgumentException(
        '$subject: content references media this diary does not own; add new '
        'files with add_diary_image or add_diary_attachment first',
      ),
      final failure => _failure(
        '$subject: the diary could not be written (${failure.name}).',
      ),
    };

Future<ToolResult> _getDiaries(
  _GetDiaryInput input,
  ToolContext ctx, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final read = await DiaryQueries(diaries: diaries).read(input.ids);
  final results = <Map<String, Object?>>[];
  for (final diary in read.found) {
    results.add(await _getDiaryPayload(diary, input, ctx, diaries, categories));
  }
  return ToolResult({'diaries': results, 'missing': read.missing});
}

Future<Map<String, Object?>> _getDiaryPayload(
  Diary diary,
  _GetDiaryInput input,
  ToolContext ctx,
  DiaryRepository diaries,
  CategoryRepository categories,
) async {
  final id = diary.id;
  final (:contentFormat, :linkStyle, :includeLinks, ids: _) = input;
  if (contentFormat == 'document' && diary.content.length > mcpResultChars) {
    _failure(
      'get_diary: the stored document of id="$id" is '
      '${diary.content.length} characters, more than the $mcpResultChars '
      'character result limit; read it as text (contentFormat="text") or as '
      'Markdown instead.',
    );
  }

  final style = linkStyle == 'label'
      ? DiaryLinkStyle.label
      : DiaryLinkStyle.uri;
  final ({Object? content, bool truncated}) projection;
  switch (contentFormat) {
    case 'document':
      projection = (
        content: TiptapContent.parse(diary.content).document ?? diary.content,
        truncated: false,
      );
    case 'text':
      projection = _capped(diaryToText(diary, linkStyle: style), ctx.surface);
    default:
      projection = _capped(
        diaryToMarkdown(diary, linkStyle: style),
        ctx.surface,
      );
  }

  final names = await categoryNames(categories);
  return {
    ..._summary(diary, categoryName: names[diary.categoryId], excerpt: 'plain'),
    'type': diary.type,
    'contentFormat': contentFormat,
    'content': projection.content,
    'contentTruncated': projection.truncated,
    'truncated': projection.truncated,
    'fullLength': contentFormat == 'text'
        ? diaryToText(diary, linkStyle: style).length
        : contentFormat == 'document'
        ? diary.content.length
        : diaryToMarkdown(diary, linkStyle: style).length,
    'placeId': diary.placeId,
    if (diary.weather case final weather?)
      'weather': {
        'icon': weather.icon,
        'temp': weather.temp,
        'text': weather.text,
      },
    'media': mediaLists(diary),
    if (includeLinks)
      'links': await DiaryToolQueries(diaries: diaries).linkSummary(diary),
    'uri': '$diaryUriPrefix${diary.id}',
  };
}

({Object? content, bool truncated}) _capped(String text, ToolSurface surface) {
  if (surface == ToolSurface.assistant && text.length > 4000) {
    var end = 3999;
    if (text.codeUnitAt(end - 1) >= 0xD800 &&
        text.codeUnitAt(end - 1) <= 0xDBFF) {
      end--;
    }
    return (content: '${text.substring(0, end)}…', truncated: true);
  }
  final capped = surface == ToolSurface.assistant ? text : truncate(text);
  return (content: capped, truncated: capped != text);
}

Future<ToolResult> _createDiary(
  _CreateDiaryInput input, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final (:content, :contentFormat, :title, :time, :mood, :tags, :categoryId) =
      input;
  final Diary diary;
  try {
    diary = await DiaryWrites(diaries: diaries, categories: categories).create(
      title: title,
      content: content,
      format: contentFormat,
      mood: mood,
      categoryId: categoryId,
      time: time,
      tags: tags,
      enforceOwnMedia: true,
    );
  } on DiaryOpsException catch (e) {
    return _writeFailure('create_diary', e, '');
  }
  return _mutation(categories, diary, created: true);
}

Future<ToolResult> _updateDiary(
  _UpdateDiaryInput input, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final (:id, :contentFormat, :patch) = input;
  try {
    return await withDiaryWriteLock(id, () async {
      final next = await DiaryWrites(diaries: diaries, categories: categories)
          .update(
            id: id,
            patch: patch,
            format: contentFormat,
            enforceOwnMedia: true,
            index: IndexMode.inline,
          );
      return _mutation(categories, next, created: false);
    });
  } on DiaryOpsException catch (e) {
    return _writeFailure('update_diary', e, id);
  }
}

Future<ToolResult> _deleteDiary(
  _DeleteDiaryInput input, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final (:id) = input;
  return withDiaryWriteLock(id, () async {
    try {
      final result = await DiaryWrites(
        diaries: diaries,
        categories: categories,
      ).delete(id: id);
      return ToolResult({
        'deleted': true,
        'id': id,
        'title': result.diary.title.trim(),
        if (result.outcome == DiaryDeleteOutcome.alreadyRecycled)
          'alreadyRecycled': true,
      });
    } on DiaryOpsException {
      return _failure('delete_diary: no diary with id="$id".');
    }
  });
}

Future<ToolResult> _searchDiaries(
  ToolContext call,
  _SearchDiariesInput input, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final (:query, :mode, :tag, :paging, :sort, :excerpt) = input;
  await _categoryFilter(paging.categoryId, 'search_diaries', categories);
  final result =
      await DiaryQueries(
        diaries: diaries,
        semantic: call.surface == ToolSurface.assistant ? call.semantic : null,
      ).search(
        query: query,
        mode: call.surface == ToolSurface.assistant ? mode : 'keyword',
        tag: tag,
        categoryId: paging.categoryId,
        start: paging.start,
        endExclusive: paging.end?.add(const Duration(microseconds: 1)),
        sort: sort,
        limit: paging.limit,
        offset: paging.offset,
      );
  final names = await categoryNames(categories);
  call.progress?.call(
    result.rows.length,
    total: result.total,
    message: 'search_diaries',
  );
  return ToolResult({
    'query': query,
    'total': result.total,
    'totalIsLowerBound': result.totalIsLowerBound,
    'offset': paging.offset,
    'limit': paging.limit,
    'hasMore':
        paging.offset + result.rows.length < result.total ||
        result.totalIsLowerBound,
    if (call.surface == ToolSurface.assistant) ...{
      'meaningRan': result.meaningRan,
      'semanticAvailable': result.semanticAvailable,
    },
    'hits': [
      for (final row in result.rows)
        {
          ..._summary(
            row.diary,
            categoryName: names[row.diary.categoryId],
            excerpt: excerpt,
          ),
          if (result.keywordHits[row.diary.id] case final hit?) ...{
            'titleHighlight': _markHighlight(hit.titleHighlight),
            'excerpt': _markHighlight(hit.excerpt),
          },
          if (query.isNotEmpty && excerpt != 'none')
            'preview': excerptOf(
              row.diary,
              renderMarkdown: excerpt == 'markdown',
            ),
          if (call.surface == ToolSurface.assistant) ...{
            'via': row.keyword && row.meaning
                ? 'keyword+meaning'
                : row.meaning
                ? 'meaning'
                : 'keyword',
            'similarity': row.score,
          },
        },
    ],
  });
}

String _markHighlight(String text) =>
    text.replaceAll(searchHitStart, '**').replaceAll(searchHitEnd, '**');

Future<ToolResult> _getDiaryLinks(
  _GetDiaryLinksInput input, {
  required DiaryRepository diaries,
}) async {
  final (:id) = input;
  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    return _failure('get_diary_links: no diary with id="$id".');
  }
  final links = await DiaryToolQueries(diaries: diaries).linkSummary(diary);
  return ToolResult({
    'id': diary.id,
    'title': diary.title,
    'time': isoUtc(diary.time),
    'timeLocal': isoLocal(diary.time),
    ...links,
  });
}

Future<ToolResult> _listTags(
  _ListTagsInput input, {
  required DiaryRepository diaries,
}) async {
  final (:limit) = input;
  final result = await DiaryToolQueries(diaries: diaries).tags(limit: limit);
  return ToolResult({
    'tags': [
      for (final entry in result.tags)
        {'tag': entry.tag, 'diaries': entry.diaries},
    ],
    'count': result.tags.length,
    'totalDistinct': result.totalDistinct,
    'scannedDiaries': result.scannedDiaries,
    'note':
        'The database has no tag index: these counts come from every visible '
        'diary.',
  });
}

typedef _GetDiaryInput = ({
  List<String> ids,
  String contentFormat,
  String linkStyle,
  bool includeLinks,
});

_GetDiaryInput _parseGetDiary(Map<String, Object?> raw) {
  final args = ToolArguments('get_diary', raw);
  final ids = (raw['ids']! as List).cast<String>();
  final contentFormat =
      args.optionalEnum('contentFormat', contentFormatValues) ?? 'markdown';
  final linkStyle = args.optionalEnum('linkStyle', linkStyleValues) ?? 'uri';
  final includeLinks = args.optionalBool('includeLinks') ?? true;

  return (
    ids: ids,
    contentFormat: contentFormat,
    linkStyle: linkStyle,
    includeLinks: includeLinks,
  );
}

typedef _CreateDiaryInput = ({
  String content,
  DiaryContentFormat contentFormat,
  String title,
  DateTime? time,
  DiaryMood? mood,
  List<String> tags,
  String? categoryId,
});

_CreateDiaryInput _parseCreateDiary(Map<String, Object?> raw) {
  final args = ToolArguments('create_diary', raw);
  final content = args.requireText('content');
  final contentFormat = _writeFormat(
    args.optionalEnum('contentFormat', contentFormatValues),
  );
  final title = args.optionalText('title') ?? '';
  final time = args.optionalDate('time');
  final mood = args.optionalMood('mood');
  final tags = args.optionalStringList('tags') ?? const <String>[];
  final categoryId = args.optionalText('categoryId');

  return (
    content: content,
    contentFormat: contentFormat,
    title: title,
    time: time,
    mood: mood,
    tags: tags,
    categoryId: categoryId,
  );
}

typedef _UpdateDiaryInput = ({
  String id,
  DiaryContentFormat contentFormat,
  DiaryPatch patch,
});

_UpdateDiaryInput _parseUpdateDiary(Map<String, Object?> raw) {
  final args = ToolArguments('update_diary', raw);
  final id = args.requireText('id');
  final contentFormat = _writeFormat(
    args.optionalEnum('contentFormat', contentFormatValues),
  );
  // Null clears nullable fields and leaves non-nullable fields unchanged.
  final patch = DiaryPatch(
    title: args.contains('title') ? args.text('title') : null,
    content: args.contains('content') ? args.requireText('content') : null,
    mood: args.has('mood') ? args.optionalMood('mood') : null,
    moodSet: args.has('mood'),
    categoryId: args.has('categoryId')
        ? (args.optionalText('categoryId') ?? '')
        : null,
    time: args.contains('time') ? args.optionalDate('time') : null,
    tags: args.has('tags')
        ? (args.optionalStringList('tags') ?? const <String>[])
        : null,
  );
  if (patch.isEmpty) {
    throw const ToolArgumentException(
      'update_diary: provide at least one field to change',
    );
  }

  return (id: id, contentFormat: contentFormat, patch: patch);
}

typedef _DeleteDiaryInput = ({String id});

_DeleteDiaryInput _parseDeleteDiary(Map<String, Object?> raw) {
  final args = ToolArguments('delete_diary', raw);
  final id = args.requireText('id');

  return (id: id);
}

typedef _SearchDiariesInput = ({
  String query,
  String mode,
  String? tag,
  _PageArgs paging,
  String? sort,
  String excerpt,
});

_SearchDiariesInput _parseSearchDiaries(Map<String, Object?> raw) {
  final args = ToolArguments('search_diaries', raw);
  return (
    query: args.optionalText('query') ?? '',
    mode: args.optionalEnum('mode', diarySearchModeValues) ?? 'auto',
    tag: args.optionalText('tag'),
    paging: _pageArgs(args),
    sort: args.optionalEnum('sort', diarySearchSortValues),
    excerpt: args.optionalEnum('excerpt', excerptValues) ?? 'plain',
  );
}

typedef _GetDiaryLinksInput = ({String id});

_GetDiaryLinksInput _parseGetDiaryLinks(Map<String, Object?> raw) {
  final args = ToolArguments('get_diary_links', raw);
  final id = args.requireText('id');
  return (id: id);
}

typedef _ListTagsInput = ({int limit});

_ListTagsInput _parseListTags(Map<String, Object?> raw) {
  final args = ToolArguments('list_tags', raw);
  final limit = args.optionalInt('limit', fallback: 50, min: 1, max: 500);

  return (limit: limit);
}

Never _failure(String message) => throw ToolFailure(message);
