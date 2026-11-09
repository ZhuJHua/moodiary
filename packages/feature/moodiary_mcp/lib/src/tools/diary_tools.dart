/// Diary read and write tools: list, read, create, update, delete, search, tags
/// and the link graph of one diary.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';
import 'arguments.dart';
import 'schemas.dart';

void registerDiaryTools(
  McpRegistry registry, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) {
  registry.addTool(
    const McpTool(
      name: 'list_diaries',
      title: 'List diaries',
      description:
          'Lists diary summaries, newest first by default: id, title, time in '
          'UTC and local time, last modification, category, mood, tags, a '
          'preview and whether the diary is visible. Bodies are not included; '
          'call get_diary for those. Page with limit and offset, hasMore says '
          'whether another page exists. tag is an exact tag match; the search '
          'index has no tag index, so a tag filter reads every visible diary '
          'and pages in memory, which is slower than the other filters. '
          'excerpt picks the preview: plain (default) is one line of plain '
          'text, markdown keeps headings and lists, none drops it.',
      inputSchema: {
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
      },
      readOnly: true,
      idempotent: true,
    ),
    (call, arguments) =>
        _listDiaries(call, arguments, diaries: diaries, categories: categories),
  );

  registry.addTool(
    const McpTool(
      name: 'get_diary',
      title: 'Read one diary',
      description:
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
      inputSchema: {
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
      },
      readOnly: true,
      idempotent: true,
    ),
    (call, arguments) =>
        _getDiary(arguments, diaries: diaries, categories: categories),
  );

  registry.addTool(
    const McpTool(
      name: 'create_diary',
      title: 'Create a diary',
      description:
          'Creates one diary and returns its summary. content is required; '
          'contentFormat=markdown (default) parses it as Markdown and stores '
          'the editor document so headings, lists and emphasis survive, text '
          'stores literal paragraphs so Markdown syntax stays visible, and '
          'document expects a Tiptap document JSON object and refuses anything '
          'else with invalid params. visible defaults to true (the summary '
          'reports it as show); title may be empty. Media is not part of the '
          'body here: attach it afterwards with add_diary_image or '
          'add_diary_attachment.',
      inputSchema: {
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
          'visible': visibleSchema,
        },
        'required': ['content'],
      },
    ),
    (call, arguments) =>
        _createDiary(arguments, diaries: diaries, categories: categories),
  );

  registry.addTool(
    const McpTool(
      name: 'update_diary',
      title: 'Update a diary',
      description:
          'Updates the given fields of one diary and leaves every omitted field '
          'unchanged; lastModified is bumped. Send null to clear a nullable '
          'field: categoryId, mood and tags (null or an empty array); '
          'title is cleared with an empty string. content, time and visible are '
          'not nullable, so an explicit null for them is ignored. content '
          'replaces the whole body and contentFormat selects how it is '
          'interpreted (markdown default, text, or document for a Tiptap '
          'document JSON object). An unknown category id is invalid params; an '
          'unknown diary id is a tool error.',
      inputSchema: {
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
          'visible': visibleSchema,
        },
        'required': ['id'],
      },
      idempotent: true,
    ),
    (call, arguments) =>
        _updateDiary(arguments, diaries: diaries, categories: categories),
  );

  registry.addTool(
    const McpTool(
      name: 'delete_diary',
      title: 'Delete a diary',
      description:
          'Deletes one diary and reports the mode that was applied. '
          'mode=permanent (default) removes the row and its local media files '
          'and leaves a sync tombstone so other devices delete it too; '
          'mode=recycle is the app recycle bin, which hides the diary '
          '(show=false) and can be undone in the app. title is the stored '
          'title, empty when the diary had none. An unknown id is a tool error.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': diaryIdSchema,
          'mode': {
            'type': 'string',
            'enum': deleteModeValues,
            'default': 'permanent',
            'description':
                'permanent removes the diary, recycle moves it to the recycle '
                'bin.',
          },
        },
        'required': ['id'],
      },
      destructive: true,
      idempotent: true,
    ),
    (call, arguments) =>
        _deleteDiary(arguments, diaries: diaries, categories: categories),
  );

  registry.addTool(
    const McpTool(
      name: 'search_diaries',
      title: 'Search diaries',
      description:
          'Full text search over diary titles and bodies; Chinese words, '
          'pinyin and Latin text all match. Search is text only: there is no '
          'tag filter here, use list_diaries tag instead. Returns the total hit '
          'count and one page of hits. Each hit carries the search '
          'highlighted titleHighlight and excerpt, where matches are wrapped in '
          '**double asterisks**, plus a preview: the excerpt projection, which '
          'is omitted with excerpt=none while the highlighted excerpt stays. '
          'sort=relevance (default) ranks by match score; newest and oldest '
          'order by diary time.',
      inputSchema: {
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
      },
      readOnly: true,
      idempotent: true,
    ),
    (call, arguments) => _searchDiaries(
      call,
      arguments,
      diaries: diaries,
      categories: categories,
    ),
  );

  registry.addTool(
    const McpTool(
      name: 'get_diary_links',
      title: 'Read diary links',
      description:
          'Lists the diaries this diary links to (forward), the diaries that '
          'link to it (backlinks) and the ids it mentions that do not exist '
          '(dangling), each with id, title and time. A dangling id is a '
          'moodiary://diary/<id> link to a diary that was deleted or never '
          'synced to this device.',
      inputSchema: {
        'type': 'object',
        'properties': {'id': diaryIdSchema},
        'required': ['id'],
      },
      readOnly: true,
      idempotent: true,
    ),
    (call, arguments) =>
        _getDiaryLinks(arguments, diaries: diaries, categories: categories),
  );

  registry.addTool(
    const McpTool(
      name: 'list_tags',
      title: 'List tags',
      description:
          'Lists the tags used by visible diaries with their usage counts, '
          'most used first. The database has no tag index, so this aggregates '
          'over every visible diary and is linear in the number of diaries.',
      inputSchema: {
        'type': 'object',
        'properties': {'limit': tagLimitSchema},
      },
      readOnly: true,
      idempotent: true,
    ),
    (call, arguments) =>
        _listTags(arguments, diaries: diaries, categories: categories),
  );
}

/// The `categoryId` filter of the list and search tools, validated up front.
///
/// An unknown id used to return an empty page, which a model reads as "that
/// category has no diaries" instead of "that category does not exist"; every
/// tool that filters by category now fails the way `create_diary` and
/// `update_diary` already did.
Future<String?> _categoryFilter(
  Args args,
  CategoryRepository categories,
) async {
  final id = args.optionalText('categoryId');
  if (id == null) return null;
  if (await categories.getCategoryById(id) == null) {
    throw JsonRpcException(
      JsonRpcCode.invalidParams,
      '${args.subject}: categoryId "$id" is not a known category; call '
      'list_categories first',
    );
  }
  return id;
}

/// One page of the in-memory tag filter.
///
/// The database has no tag index, so the tag filter has to read the visible
/// diaries (already in the requested order) and page here; it is linear in the
/// number of diaries, like `list_tags`.
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

/// A diary summary with the requested excerpt projection.
///
/// [diarySummary] always fills `excerpt`; `excerpt=none` is this catalog's way
/// of asking for smaller summaries, so the key is dropped rather than sent
/// empty.
Map<String, dynamic> _summary(
  Diary diary, {
  String? categoryName,
  required String excerpt,
}) {
  final summary = diarySummary(
    diary,
    categoryName: categoryName,
    renderMarkdown: excerpt == 'markdown',
  );
  if (excerpt == 'none') summary.remove('excerpt');
  return summary;
}

/// The mutation result shape the write tools answer with.
Future<McpToolResult> _mutation(
  DiaryRepository diaries,
  CategoryRepository categories,
  Diary diary, {
  required bool created,
}) async {
  final names = await categoryNames(categories);
  return McpToolResult.json({
    if (created) 'created': true else 'updated': true,
    'diary': _summary(
      diary,
      categoryName: names[diary.categoryId],
      excerpt: 'plain',
    ),
  });
}

/// Maps the `contentFormat` argument of a write tool onto the shared codec;
/// absent means Markdown, the same default as the assistant tools.
DiaryContentFormat _writeFormat(String? value) => switch (value) {
  'text' => DiaryContentFormat.plainText,
  'document' => DiaryContentFormat.document,
  _ => DiaryContentFormat.markdown,
};

/// Maps a write failure onto the tool surface: a bad argument is invalid params
/// (`-32602`, the client can repair the call), a missing row is an `isError`
/// result (the call itself was well formed).
McpToolResult _writeFailure(String subject, DiaryOpsException e, String id) =>
    switch (e.failure) {
      DiaryOpsFailure.invalidCategory => throw JsonRpcException(
        JsonRpcCode.invalidParams,
        '$subject: categoryId "${e.categoryId}" is not a known category; call '
        'list_categories first',
      ),
      DiaryOpsFailure.invalidDocument => throw JsonRpcException(
        JsonRpcCode.invalidParams,
        '$subject: content is not a Tiptap document; contentFormat="document" '
        'expects a JSON object with type "doc"',
      ),
      DiaryOpsFailure.emptyContent => throw JsonRpcException(
        JsonRpcCode.invalidParams,
        '$subject: content must not be empty',
      ),
      DiaryOpsFailure.noChanges => throw JsonRpcException(
        JsonRpcCode.invalidParams,
        '$subject: provide at least one field to change',
      ),
      DiaryOpsFailure.notFound => McpToolResult.error(
        '$subject: no diary with id="$id".',
      ),
      final failure => McpToolResult.error(
        '$subject: the diary could not be written (${failure.name}).',
      ),
    };

Future<McpToolResult> _listDiaries(
  McpCallContext call,
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final args = Args('list_diaries', arguments);
  final categoryId = await _categoryFilter(args, categories);
  final tag = args.optionalText('tag');
  final start = args.optionalDate('startDate');
  final end = args.optionalDate('endDate', endOfDay: true);
  args.requireOrderedRange(start, end);
  final sort = switch (args.optionalEnum('sort', diarySortValues)) {
    'oldest' => DiarySort.timeAsc,
    'modified' => DiarySort.lastModifiedDesc,
    _ => DiarySort.timeDesc,
  };
  final excerpt = args.optionalEnum('excerpt', excerptValues) ?? 'plain';
  final limit = args.optionalInt('limit', fallback: 20, min: 1, max: 100);
  final offset = args.optionalInt('offset', fallback: 0, min: 0, max: 1000000);

  final List<Diary> page;
  if (tag == null) {
    page = await DiaryQueries(diaries: diaries).page(
      categoryId: categoryId,
      start: start,
      end: end,
      sort: sort,
      offset: offset,
      limit: limit + 1,
    );
  } else {
    page = _tagPage(
      await diaries.getDiaryByCategory(sort: sort),
      tag: tag,
      categoryId: categoryId,
      start: start,
      end: end,
      offset: offset,
      limit: limit + 1,
    );
  }
  final names = await categoryNames(categories);
  final rows = page.take(limit).toList();
  call.reportProgress(rows.length, message: 'list_diaries');
  return McpToolResult.json({
    'diaries': [
      for (final diary in rows)
        _summary(
          diary,
          categoryName: names[diary.categoryId],
          excerpt: excerpt,
        ),
    ],
    'count': rows.length,
    'offset': offset,
    'limit': limit,
    'hasMore': page.length > limit,
  });
}

Future<McpToolResult> _getDiary(
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final args = Args('get_diary', arguments);
  final id = args.requireText('id');
  final contentFormat =
      args.optionalEnum('contentFormat', readContentFormatValues) ?? 'markdown';
  final linkStyle = args.optionalEnum('linkStyle', linkStyleValues) ?? 'uri';
  final includeLinks = args.optionalBool('includeLinks') ?? true;

  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null) {
    return McpToolResult.error('get_diary: no diary with id="$id".');
  }
  if (contentFormat == 'document' && diary.content.length > mcpResultChars) {
    return McpToolResult.error(
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
        content: decodeJsonOrText(TiptapContent.normalize(diary.content)),
        truncated: false,
      );
    case 'text':
      projection = _capped(diaryToText(diary, linkStyle: style));
    default:
      projection = _capped(diaryToMarkdown(diary, linkStyle: style));
  }

  final names = await categoryNames(categories);
  return McpToolResult.json({
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
    'media': {
      'images': diary.imageName,
      'audio': diary.audioName,
      'videos': diary.videoName,
      'files': diary.fileName,
    },
    if (includeLinks)
      'links': await DiaryQueries(diaries: diaries).linkSummary(diary),
    'uri': '$diaryUriPrefix${diary.id}',
  });
}

/// Caps a rendered body at the result limit and reports whether it was cut.
({Object? content, bool truncated}) _capped(String text) {
  final capped = truncate(text);
  return (content: capped, truncated: capped != text);
}

Future<McpToolResult> _createDiary(
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final args = Args('create_diary', arguments);
  final content = args.requireText('content');
  final contentFormat = _writeFormat(
    args.optionalEnum('contentFormat', writeContentFormatValues),
  );
  final title = args.optionalText('title') ?? '';
  final time = args.optionalDate('time');
  final mood = args.optionalMood('mood');
  final tags = args.optionalStringList('tags') ?? const <String>[];
  final visible = args.optionalBool('visible') ?? true;
  final categoryId = args.optionalText('categoryId');

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
      show: visible,
    );
  } on DiaryOpsException catch (e) {
    return _writeFailure('create_diary', e, '');
  }
  return _mutation(diaries, categories, diary, created: true);
}

Future<McpToolResult> _updateDiary(
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final args = Args('update_diary', arguments);
  final id = args.requireText('id');
  final contentFormat = _writeFormat(
    args.optionalEnum('contentFormat', writeContentFormatValues),
  );
  // Nullable fields read `has`, so a sent null (or an empty string for a text
  // field) clears them; the non-nullable ones read `contains`, so an explicit
  // null leaves them untouched.
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
    show: args.contains('visible') ? args.optionalBool('visible') : null,
  );
  if (patch.isEmpty) {
    throw const JsonRpcException(
      JsonRpcCode.invalidParams,
      'update_diary: provide at least one field to change',
    );
  }

  try {
    final next = await DiaryWrites(diaries: diaries, categories: categories)
        .update(
          id: id,
          patch: patch,
          format: contentFormat,
          index: IndexMode.inline,
        );
    return await _mutation(diaries, categories, next, created: false);
  } on DiaryOpsException catch (e) {
    return _writeFailure('update_diary', e, id);
  }
}

Future<McpToolResult> _deleteDiary(
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final args = Args('delete_diary', arguments);
  final id = args.requireText('id');
  final mode = args.optionalEnum('mode', deleteModeValues) ?? 'permanent';
  final recycle = mode == 'recycle';

  try {
    final result = await DiaryWrites(diaries: diaries, categories: categories)
        .delete(
          id: id,
          mode: recycle ? DiaryDeleteMode.recycle : DiaryDeleteMode.permanent,
        );
    return McpToolResult.json({
      'deleted': true,
      'id': id,
      'title': result.diary.title.trim(),
      'mode': mode,
    });
  } on DiaryOpsException {
    return McpToolResult.error('delete_diary: no diary with id="$id".');
  }
}

Future<McpToolResult> _searchDiaries(
  McpCallContext call,
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final args = Args('search_diaries', arguments);
  final query = args.requireText('query');
  final categoryId = await _categoryFilter(args, categories);
  final start = args.optionalDate('startDate');
  final end = args.optionalDate('endDate', endOfDay: true);
  args.requireOrderedRange(start, end);
  final sort = switch (args.optionalEnum('sort', searchSortValues)) {
    'newest' => SearchSort.timeDesc,
    'oldest' => SearchSort.timeAsc,
    _ => SearchSort.relevance,
  };
  final excerpt = args.optionalEnum('excerpt', excerptValues) ?? 'plain';
  final limit = args.optionalInt('limit', fallback: 20, min: 1, max: 100);
  final offset = args.optionalInt('offset', fallback: 0, min: 0, max: 1000000);
  final endExclusive = end?.add(const Duration(microseconds: 1));

  // The repository is asked directly instead of going through
  // `DiaryQueries.searchPage` because the `sort` argument has to reach the
  // index ordering; the two calls are the same pair searchPage makes.
  final total = await diaries.countSearchDiaries(
    query: query,
    categoryId: categoryId,
    start: start,
    end: endExclusive,
  );
  final hits = await diaries.searchDiaries(
    query: query,
    categoryId: categoryId,
    start: start,
    end: endExclusive,
    sort: sort,
    limit: limit,
    offset: offset,
  );
  final names = await categoryNames(categories);
  call.reportProgress(hits.length, total: total, message: 'search_diaries');
  return McpToolResult.json({
    'query': query,
    'total': total,
    'offset': offset,
    'limit': limit,
    'hasMore': offset + hits.length < total,
    'hits': [
      for (final hit in hits)
        {
          // The search snippet replaces the summary's `excerpt`, so the summary
          // keeps its default plain projection and only `preview` follows the
          // `excerpt` argument.
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

/// The search index wraps matches in control characters; models read Markdown
/// emphasis far better, so the sentinels become `**`.
String _markHighlight(String text) =>
    text.replaceAll(searchHitStart, '**').replaceAll(searchHitEnd, '**');

Future<McpToolResult> _getDiaryLinks(
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final args = Args('get_diary_links', arguments);
  final id = args.requireText('id');
  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null) {
    return McpToolResult.error('get_diary_links: no diary with id="$id".');
  }
  final links = await DiaryQueries(diaries: diaries).linkSummary(diary);
  return McpToolResult.json({
    'id': diary.id,
    'title': diary.title,
    'time': isoUtc(diary.time),
    'timeLocal': isoLocal(diary.time),
    ...links,
  });
}

Future<McpToolResult> _listTags(
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final args = Args('list_tags', arguments);
  final limit = args.optionalInt('limit', fallback: 50, min: 1, max: 500);

  final result = await DiaryQueries(diaries: diaries).tags(limit: limit);
  return McpToolResult.json({
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
