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
    name: 'list_diaries',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('list_diaries', result.data),
    title: 'List diaries',
    description: (_) =>
        'Lists diary summaries, newest first by default: id, title, time in '
        'UTC and local time, last modification, category, mood, tags, a '
        'preview and whether the diary is visible. Bodies are not included; '
        'call get_diary for those. Page with limit and offset, hasMore says '
        'whether another page exists. tag is an exact tag match; the search '
        'index has no tag index, so a tag filter reads every visible diary '
        'and pages in memory, which is slower than the other filters. '
        'excerpt picks the preview: plain (default) is one line of plain '
        'text, markdown keeps headings and lists, none drops it.',
    input: (_) => Schema.fromMap({
      'type': 'object',
      'properties': {
        'categoryId': categoryIdSchema,
        'tag': {
          'type': 'string',
          'description':
              'Exact tag to filter by, as list_tags spells it '
              '(case-sensitive).',
        },
        'startDate': startDateSchema,
        'endDate': endDateSchema,
        'sort': diarySortSchema,
        'limit': limitSchema,
        'offset': offsetSchema,
        'excerpt': excerptSchema,
      },
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: toolOutputSchema('list_diaries'),
    parse: _parseListDiaries,
    run: (input, ctx) => _listDiaries(
      ctx,
      input,
      diaries: ctx.diaries,
      categories: ctx.categories,
    ),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'get_diary',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('get_diary', result.data),
    title: 'Read one diary',
    description: (_) =>
        'Reads one diary with its metadata. contentFormat=markdown (default) '
        'renders the stored document as Markdown; text returns the plain body '
        '(no syntax, media as [image: name] placeholders); document returns '
        'the raw stored Tiptap document as a JSON object and is subject to '
        'the $mcpResultChars character result limit. linkStyle=uri (default) '
        'renders a diary mention as [label](moodiary://diary/<id>), label '
        'keeps only the label. includeLinks=false omits the links graph '
        '(forward links, backlinks and dangling ids). The result also carries '
        'the summary fields, type, media file names, the recorded place and '
        'weather, and the moodiary:// URI. Attach media with add_diary_image '
        'or add_diary_attachment; read it with list_diary_media.',
    input: (_) => Schema.fromMap({
      'type': 'object',
      'properties': {
        'id': diaryIdSchema,
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
      'required': ['id'],
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: toolOutputSchema('get_diary'),
    parse: _parseGetDiary,
    run: (input, ctx) =>
        _getDiary(input, diaries: ctx.diaries, categories: ctx.categories),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'create_diary',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('create_diary', result.data),
    title: 'Create a diary',
    description: (_) =>
        'Creates one diary and returns its summary. content is required; '
        'contentFormat=markdown (default) parses it as Markdown and stores '
        'the editor document so headings, lists and emphasis survive, text '
        'stores literal paragraphs so Markdown syntax stays visible, and '
        'document expects a Tiptap document JSON object and refuses anything '
        'else with invalid params. The new diary is visible (the summary '
        'reports it as show); title may be empty. The body may not reference '
        'media: a body with media nodes is invalid params, because media has '
        'to be added to an existing diary with add_diary_image or '
        'add_diary_attachment (which also creates its media index row).',
    input: (_) => Schema.fromMap({
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
        'time': {
          'type': 'string',
          'description':
              'ISO-8601 instant the diary is about. A bare yyyy-MM-dd means '
              'local midnight. Defaults to now.',
        },
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
    parse: _parseCreateDiary,
    run: (input, ctx) =>
        _createDiary(input, diaries: ctx.diaries, categories: ctx.categories),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'update_diary',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('update_diary', result.data),
    title: 'Update a diary',
    description: (_) =>
        'Updates the given fields of one diary and leaves every omitted field '
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
        'invalid params; an unknown diary id is a tool error.',
    input: (_) => Schema.fromMap({
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
        'time': {
          'type': 'string',
          'description':
              'New ISO-8601 instant. A bare yyyy-MM-dd means local midnight. '
              'An explicit null is ignored.',
        },
        'categoryId': categoryIdSchema,
        'mood': moodSchema,
        'tags': tagsSchema,
      },
      'required': ['id'],
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.destructive,
    idempotent: true,
    output: toolOutputSchema('update_diary'),
    parse: _parseUpdateDiary,
    run: (input, ctx) =>
        _updateDiary(input, diaries: ctx.diaries, categories: ctx.categories),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'delete_diary',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('delete_diary', result.data),
    title: 'Delete a diary',
    description: (_) =>
        'Moves one diary to the recycle bin (show=false). This can be undone '
        'in the app. Permanent deletion is only available in the app. title '
        'is the stored title, empty when the diary had none. An unknown id '
        'is a tool error.',
    input: (_) => Schema.fromMap({
      'type': 'object',
      'properties': {'id': diaryIdSchema},
      'required': ['id'],
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.destructive,
    idempotent: true,
    output: toolOutputSchema('delete_diary'),
    parse: _parseDeleteDiary,
    run: (input, ctx) =>
        _deleteDiary(input, diaries: ctx.diaries, categories: ctx.categories),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'search_diaries',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('search_diaries', result.data),
    title: 'Search diaries',
    description: (_) =>
        'Full text search over diary titles and bodies; Chinese words, '
        'pinyin and Latin text all match. There is no '
        'tag filter here, use list_diaries tag instead. Returns the total hit '
        'count and one page of hits. Each hit carries the search '
        'highlighted titleHighlight and excerpt, where matches are wrapped in '
        '**double asterisks**, plus a preview: the excerpt projection, which '
        'is omitted with excerpt=none while the highlighted excerpt stays. '
        'sort=relevance (default) ranks by match score; newest and oldest '
        'order by diary time.',
    input: (_) => Schema.fromMap({
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'Words to search for; required.',
        },
        'categoryId': categoryIdSchema,
        'startDate': startDateSchema,
        'endDate': endDateSchema,
        'sort': searchSortSchema,
        'limit': limitSchema,
        'offset': offsetSchema,
        'excerpt': excerptSchema,
      },
      'required': ['query'],
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

/// Tag filtering scans all visible diaries because tags have no index.
List<Diary> _tagPage(
  List<Diary> visible, {
  required String tag,
  required String? categoryId,
  required DateTime? start,
  required DateTime? end,
  required int offset,
  required int limit,
}) {
  final matched = [
    for (final diary in visible)
      if (diary.tags.contains(tag) &&
          (categoryId == null || diary.categoryId == categoryId) &&
          (start == null || !diary.time.isBefore(start)) &&
          (end == null || !diary.time.isAfter(end)))
        diary,
  ];
  return matched.skip(offset).take(limit).toList();
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

Future<ToolResult> _listDiaries(
  ToolContext call,
  _ListDiariesInput input, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final (:paging, :tag, :sort, :excerpt) = input;
  await _categoryFilter(paging.categoryId, 'list_diaries', categories);
  final List<Diary> page;
  if (tag == null) {
    page = await DiaryToolQueries(diaries: diaries).page(
      categoryId: paging.categoryId,
      start: paging.start,
      end: paging.end,
      sort: sort,
      offset: paging.offset,
      limit: paging.limit + 1,
    );
  } else {
    page = _tagPage(
      await diaries.getDiaryByCategory(sort: sort),
      tag: tag,
      categoryId: paging.categoryId,
      start: paging.start,
      end: paging.end,
      offset: paging.offset,
      limit: paging.limit + 1,
    );
  }
  final names = await categoryNames(categories);
  final rows = page.take(paging.limit).toList();
  call.progress?.call(rows.length, message: 'list_diaries');
  return ToolResult({
    'diaries': [
      for (final diary in rows)
        _summary(
          diary,
          categoryName: names[diary.categoryId],
          excerpt: excerpt,
        ),
    ],
    'count': rows.length,
    'offset': paging.offset,
    'limit': paging.limit,
    'hasMore': page.length > paging.limit,
  });
}

Future<ToolResult> _getDiary(
  _GetDiaryInput input, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final (:id, :contentFormat, :linkStyle, :includeLinks) = input;
  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    return _failure('get_diary: no diary with id="$id".');
  }
  if (contentFormat == 'document' && diary.content.length > mcpResultChars) {
    return _failure(
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
      projection = _capped(diaryToText(diary, linkStyle: style));
    default:
      projection = _capped(diaryToMarkdown(diary, linkStyle: style));
  }

  final names = await categoryNames(categories);
  return ToolResult({
    ..._summary(diary, categoryName: names[diary.categoryId], excerpt: 'plain'),
    'type': diary.type,
    'contentFormat': contentFormat,
    'content': projection.content,
    'contentTruncated': projection.truncated,
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
  });
}

({Object? content, bool truncated}) _capped(String text) {
  final capped = truncate(text);
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
  final (:query, :paging, :sort, :excerpt, :endExclusive) = input;
  await _categoryFilter(paging.categoryId, 'search_diaries', categories);
  final total = await diaries.countSearchDiaries(
    query: query,
    categoryId: paging.categoryId,
    start: paging.start,
    end: endExclusive,
  );
  final hits = await diaries.searchDiaries(
    query: query,
    categoryId: paging.categoryId,
    start: paging.start,
    end: endExclusive,
    sort: sort,
    limit: paging.limit,
    offset: paging.offset,
  );
  final names = await categoryNames(categories);
  call.progress?.call(hits.length, total: total, message: 'search_diaries');
  return ToolResult({
    'query': query,
    'total': total,
    'offset': paging.offset,
    'limit': paging.limit,
    'hasMore': paging.offset + hits.length < total,
    'hits': [
      for (final hit in hits)
        {
          ..._summary(
            hit.diary,
            categoryName: names[hit.diary.categoryId],
            excerpt: 'plain',
          ),
          'titleHighlight': _markHighlight(hit.titleHighlight),
          'excerpt': _markHighlight(hit.excerpt),
          if (excerpt != 'none')
            'preview': excerptOf(
              hit.diary,
              renderMarkdown: excerpt == 'markdown',
            ),
        },
    ],
  });
}

/// Convert the search index sentinels to Markdown emphasis.
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

typedef _ListDiariesInput = ({
  _PageArgs paging,
  String? tag,
  DiarySort sort,
  String excerpt,
});

_ListDiariesInput _parseListDiaries(Map<String, Object?> raw) {
  final args = ToolArguments('list_diaries', raw);
  final paging = _pageArgs(args);
  final tag = args.optionalText('tag');
  final sort = parseDiarySort(args.optionalEnum('sort', diarySortValues));
  final excerpt = args.optionalEnum('excerpt', excerptValues) ?? 'plain';

  return (paging: paging, tag: tag, sort: sort, excerpt: excerpt);
}

typedef _GetDiaryInput = ({
  String id,
  String contentFormat,
  String linkStyle,
  bool includeLinks,
});

_GetDiaryInput _parseGetDiary(Map<String, Object?> raw) {
  final args = ToolArguments('get_diary', raw);
  final id = args.requireText('id');
  final contentFormat =
      args.optionalEnum('contentFormat', contentFormatValues) ?? 'markdown';
  final linkStyle = args.optionalEnum('linkStyle', linkStyleValues) ?? 'uri';
  final includeLinks = args.optionalBool('includeLinks') ?? true;

  return (
    id: id,
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
  _PageArgs paging,
  SearchSort sort,
  String excerpt,
  DateTime? endExclusive,
});

_SearchDiariesInput _parseSearchDiaries(Map<String, Object?> raw) {
  final args = ToolArguments('search_diaries', raw);
  final query = args.requireText('query');
  final paging = _pageArgs(args);
  final sort = switch (args.optionalEnum('sort', searchSortValues)) {
    'newest' => SearchSort.timeDesc,
    'oldest' => SearchSort.timeAsc,
    _ => SearchSort.relevance,
  };
  final excerpt = args.optionalEnum('excerpt', excerptValues) ?? 'plain';
  final endExclusive = paging.end?.add(const Duration(microseconds: 1));

  return (
    query: query,
    paging: paging,
    sort: sort,
    excerpt: excerpt,
    endExclusive: endExclusive,
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
