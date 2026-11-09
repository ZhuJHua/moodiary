/// Diary read and write tools: list, read, create, update, soft delete, search,
/// tags and the link graph of one diary.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';
import 'arguments.dart';

/// Both accepted shapes of the `sort` argument.
const List<String> _sortValues = ['timeDesc', 'timeAsc'];

/// Body representations `get_diary` can answer with. The first two are raw
/// stored documents and win over `renderMarkdown`.
const List<String> _contentFormats = ['markdown', 'text', 'tiptap', 'json'];

/// How `create_diary` and `update_diary` interpret the body they are handed.
const List<String> _writeContentFormats = ['markdown', 'text'];

const Map<String, dynamic> _categoryIdSchema = {
  'type': 'string',
  'description': 'Only diaries filed under this category id.',
};

const Map<String, dynamic> _startSchema = {
  'type': 'string',
  'description':
      'Inclusive ISO-8601 lower bound on the diary time. A bare yyyy-MM-dd '
      'means local midnight of that day.',
};

const Map<String, dynamic> _endSchema = {
  'type': 'string',
  'description':
      'Inclusive ISO-8601 upper bound on the diary time. A bare yyyy-MM-dd '
      'covers that whole local day.',
};

const Map<String, dynamic> _limitSchema = {
  'type': 'integer',
  'minimum': 1,
  'maximum': 100,
  'default': 20,
  'description': 'Page size, capped at 100.',
};

const Map<String, dynamic> _offsetSchema = {
  'type': 'integer',
  'minimum': 0,
  'default': 0,
  'description': 'Number of matching diaries to skip.',
};

const Map<String, dynamic> _idSchema = {
  'type': 'string',
  'description': 'Diary id (uuid v7) as returned by the list tools.',
};

/// The excerpt projection flag shared by the list shaped read tools.
const Map<String, dynamic> _renderMarkdownExcerptSchema = {
  'type': 'boolean',
  'default': false,
  'description':
      'false keeps the single line plain excerpt; true returns the Markdown '
      'body cut to $mcpExcerptChars characters, so headings and lists survive.',
};

/// The body representation a write tool parses its `content` with.
const Map<String, dynamic> _writeContentFormatSchema = {
  'type': 'string',
  'enum': _writeContentFormats,
  'default': 'markdown',
  'description':
      'markdown parses content as Markdown and stores the editor document '
      '(formatting is preserved); text stores it as plain text paragraphs, so '
      'Markdown syntax stays literal. Applies only to content.',
};

const Map<String, dynamic> _moodSchema = {
  'description':
      'Mood as awful, bad, okay, good or great, or as a score from 1 to 5. An '
      'empty string clears it.',
  'oneOf': [
    {
      'type': 'string',
      'enum': ['awful', 'bad', 'okay', 'good', 'great'],
    },
    {'type': 'integer', 'minimum': 1, 'maximum': 5},
  ],
};

const Map<String, dynamic> _tagsSchema = {
  'type': 'array',
  'items': {'type': 'string'},
  'description': 'Replaces the whole tag list; the order is kept.',
};

const Map<String, dynamic> _timeSchema = {
  'type': 'string',
  'description':
      'ISO-8601 instant the diary is about. A bare yyyy-MM-dd means local '
      "midnight. Defaults to now for create and is left unchanged by update.",
};

const String _mediaRefusal =
    'Media cannot be attached through MCP: images, audio, video and file '
    'attachments only come from the app editor. Argument level media fields '
    'are rejected, and replacing the body drops the media references the new '
    'body no longer contains.';

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
          'UTC and local time, last modified, category, mood, tags, an excerpt '
          'and whether the diary is visible. The excerpt is a single line of '
          'plain text up to 200 characters; set renderMarkdown=true to get the '
          'Markdown body cut to the same length instead. Page with limit and '
          'offset. Bodies are not included; call get_diary for those.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'categoryId': _categoryIdSchema,
          'start': _startSchema,
          'end': _endSchema,
          'sort': {
            'type': 'string',
            'enum': _sortValues,
            'default': 'timeDesc',
            'description': 'Diary time order.',
          },
          'renderMarkdown': _renderMarkdownExcerptSchema,
          'limit': _limitSchema,
          'offset': _offsetSchema,
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
          'Reads one diary with its metadata. format=markdown (default) renders '
          'the stored document as Markdown; text returns the plain text body; '
          'json and tiptap return the raw stored document (tiptap normalized to '
          'the current schema version) and win over renderMarkdown. '
          'renderMarkdown=false returns the plain text body instead of Markdown '
          '(no syntax, media as [image: name] placeholders). renderLinks=false '
          'renders a diary link (double link) as its label text instead of '
          '[label](moodiary://diary/<id>); it only affects Markdown output. '
          'contentFormat reports the representation actually returned. Returns '
          'metadata too: category, mood, tags, time, media file names and diary '
          'links. '
          '$_mediaRefusal',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': _idSchema,
          'format': {
            'type': 'string',
            'enum': _contentFormats,
            'default': 'markdown',
            'description':
                'Body representation. tiptap and json ignore the render flags '
                'and return the raw document.',
          },
          'renderMarkdown': {
            'type': 'boolean',
            'default': true,
            'description':
                'false returns the plain text body instead of Markdown: no '
                'syntax and media as [image: name] placeholders. Ignored when '
                'format is tiptap or json.',
          },
          'renderLinks': {
            'type': 'boolean',
            'default': true,
            'description':
                'false renders diary links (double links) as their label text '
                'instead of [label](moodiary://diary/<id>). Ignored unless '
                'Markdown is returned.',
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
          'Creates one diary. content is parsed as Markdown by default and '
          'stored through the editor conversion, so formatting such as headings, '
          'lists and emphasis is preserved; set contentFormat=text to store it '
          'as plain text paragraphs, where Markdown syntax stays literal. Read '
          'the result back with get_diary. Returns the new id and its summary. '
          'Media cannot be added here: '
          '$_mediaRefusal',
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
                'Diary body; required. Parsed as Markdown unless '
                'contentFormat=text.',
          },
          'contentFormat': _writeContentFormatSchema,
          'time': _timeSchema,
          'categoryId': _categoryIdSchema,
          'mood': _moodSchema,
          'tags': _tagsSchema,
          'show': {
            'type': 'boolean',
            'default': true,
            'description': 'false files the diary in the recycle bin.',
          },
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
          'Updates the given fields of one diary and leaves every other field '
          'alone; lastModified is bumped. content replaces the whole body, '
          'parsed as Markdown by default so formatting is kept, or as plain text '
          'paragraphs with contentFormat=text. Send an empty string for '
          'categoryId or mood to clear it. $_mediaRefusal',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': _idSchema,
          'title': {
            'type': 'string',
            'description': 'New title; an empty string clears it.',
          },
          'content': {
            'type': 'string',
            'description':
                'New body; replaces the old one. Parsed as Markdown unless '
                'contentFormat=text.',
          },
          'contentFormat': _writeContentFormatSchema,
          'time': _timeSchema,
          'categoryId': {
            'type': 'string',
            'description':
                'New category id; an empty string removes the category.',
          },
          'mood': _moodSchema,
          'tags': _tagsSchema,
          'show': {
            'type': 'boolean',
            'description':
                'true keeps the diary visible, false moves it to the recycle '
                'bin.',
          },
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
          "Deletes one diary and reports whether it existed. mode=delete "
          '(default) removes the diary row and its local media files and leaves '
          'a sync tombstone so other devices delete it too. mode=recycle is the '
          "app's recycle bin: the diary is hidden (show=false) and can be "
          'restored from the app.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': _idSchema,
          'mode': {
            'type': 'string',
            'enum': ['delete', 'recycle'],
            'default': 'delete',
            'description': 'Permanent delete versus moving to the recycle bin.',
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
          'Full text search over diary titles and bodies (Chinese words, pinyin '
          'and Latin text all match). Returns the total hit count and one page '
          'of hits. Each hit carries the search-highlighted excerpt, where '
          'matches are wrapped in **double asterisks**, plus a preview: the '
          'single line plain body by default, or the Markdown body cut to '
          '$mcpExcerptChars characters when renderMarkdown=true. The excerpt is '
          'always the plain search snippet.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Words to search for; required.',
          },
          'categoryId': _categoryIdSchema,
          'start': _startSchema,
          'end': _endSchema,
          'renderMarkdown': _renderMarkdownExcerptSchema,
          'limit': _limitSchema,
          'offset': _offsetSchema,
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
          'Lists the diaries this diary links to (forward links) and the diaries '
          'that link to it (backlinks), with id, title and time.',
      inputSchema: {
        'type': 'object',
        'properties': {'id': _idSchema},
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
        'properties': {
          'limit': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 500,
            'default': 50,
            'description': 'Number of tags to return, capped at 500.',
          },
        },
      },
      readOnly: true,
      idempotent: true,
    ),
    (call, arguments) =>
        _listTags(arguments, diaries: diaries, categories: categories),
  );
}

Future<McpToolResult> _listDiaries(
  McpCallContext call,
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final args = Args('list_diaries', arguments);
  final categoryId = args.optionalText('categoryId');
  final start = args.optionalDate('start');
  final end = args.optionalDate('end', endOfDay: true);
  args.requireOrderedRange(start, end);
  final sort = args.optionalEnum('sort', _sortValues) ?? 'timeDesc';
  final renderMarkdown = args.optionalBool('renderMarkdown') ?? false;
  final limit = args.optionalInt('limit', fallback: 20, min: 1, max: 100);
  final offset = args.optionalInt('offset', fallback: 0, min: 0, max: 1000000);

  final page = await DiaryQueries(diaries: diaries).page(
    categoryId: categoryId,
    start: start,
    end: end,
    sort: sort == 'timeAsc' ? DiarySort.timeAsc : DiarySort.timeDesc,
    offset: offset,
    limit: limit + 1,
  );
  final names = await categoryNames(categories);
  final diaries_ = page.take(limit).toList();
  call.reportProgress(diaries_.length, message: 'list_diaries');
  return McpToolResult.json({
    'diaries': [
      for (final diary in diaries_)
        diarySummary(
          diary,
          categoryName: names[diary.categoryId],
          renderMarkdown: renderMarkdown,
        ),
    ],
    'count': diaries_.length,
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
  final requestedFormat =
      args.optionalEnum('format', _contentFormats) ?? 'markdown';
  final renderMarkdown = args.optionalBool('renderMarkdown') ?? true;
  final renderLinks = args.optionalBool('renderLinks') ?? true;
  final rawFormat = requestedFormat == 'tiptap' || requestedFormat == 'json';

  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null) {
    return McpToolResult.error('get_diary: no diary with id="$id".');
  }
  final names = await categoryNames(categories);
  if (rawFormat && diary.content.length > mcpResultChars) {
    return McpToolResult.error(
      'get_diary: the stored document of id="$id" is '
      '${diary.content.length} characters, more than the $mcpResultChars '
      'character result limit; read it as plain text with renderMarkdown=false '
      'or format="text" instead.',
    );
  }

  final ({Object? content, bool truncated}) projection;
  final String format;
  if (requestedFormat == 'tiptap') {
    projection = (
      content: decodeJsonOrText(TiptapContent.normalize(diary.content)),
      truncated: false,
    );
    format = 'tiptap';
  } else if (requestedFormat == 'json') {
    projection = (content: decodeJsonOrText(diary.content), truncated: false);
    format = 'json';
  } else if (requestedFormat == 'text') {
    projection = _capped(diaryToText(diary));
    format = 'text';
  } else if (renderMarkdown) {
    projection = _capped(diaryToMarkdown(diary, renderLinks: renderLinks));
    format = 'markdown';
  } else {
    projection = _capped(diaryToText(diary));
    format = 'text';
  }

  final links = await DiaryQueries(diaries: diaries).linkSummary(diary);
  return McpToolResult.json({
    ...diarySummary(diary, categoryName: names[diary.categoryId]),
    'type': diary.type,
    'contentFormat': format,
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
    'links': links,
    'uri': '$diaryUriPrefix${diary.id}',
  });
}

/// Caps a rendered body at the result limit and reports whether it was cut.
({Object? content, bool truncated}) _capped(String text) {
  final capped = truncate(text);
  return (content: capped, truncated: capped != text);
}

/// Maps the `contentFormat` argument onto the shared write codec; absent means
/// Markdown, the same default as the assistant tools.
DiaryContentFormat _writeFormat(String? value) => value == 'text'
    ? DiaryContentFormat.plainText
    : DiaryContentFormat.markdown;

Future<McpToolResult> _createDiary(
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final args = Args('create_diary', arguments);
  args.rejectMediaArguments();
  final content = args.requireText('content');
  final contentFormat = _writeFormat(
    args.optionalEnum('contentFormat', _writeContentFormats),
  );
  final title = args.optionalText('title') ?? '';
  final time = args.optionalDate('time');
  final mood = args.optionalMood('mood');
  final tags = args.optionalStringList('tags') ?? const <String>[];
  final show = args.optionalBool('show') ?? true;
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
      show: show,
    );
  } on DiaryOpsException catch (e) {
    if (e.failure == DiaryOpsFailure.invalidCategory) {
      throw JsonRpcException(
        JsonRpcCode.invalidParams,
        'create_diary: categoryId "${e.categoryId}" is not a known category; '
        'call list_categories first',
      );
    }
    rethrow;
  }
  return _createdOrUpdated(diaries, categories, diary, created: true);
}

Future<McpToolResult> _updateDiary(
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final args = Args('update_diary', arguments);
  args.rejectMediaArguments();
  final id = args.requireText('id');
  final contentFormat = _writeFormat(
    args.optionalEnum('contentFormat', _writeContentFormats),
  );
  final patch = DiaryPatch(
    title: args.contains('title') ? args.text('title') : null,
    content: args.contains('content') ? args.requireText('content') : null,
    mood: args.contains('mood') ? args.optionalMood('mood') : null,
    moodSet: args.contains('mood'),
    categoryId: args.contains('categoryId')
        ? (args.optionalText('categoryId') ?? '')
        : null,
    time: args.contains('time') ? args.optionalDate('time') : null,
    tags: args.contains('tags')
        ? (args.optionalStringList('tags') ?? const <String>[])
        : null,
    show: args.contains('show') ? args.optionalBool('show') : null,
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
    return await _createdOrUpdated(diaries, categories, next, created: false);
  } on DiaryOpsException catch (e) {
    return switch (e.failure) {
      DiaryOpsFailure.notFound => McpToolResult.error(
        'update_diary: no diary with id="$id".',
      ),
      DiaryOpsFailure.invalidCategory => throw JsonRpcException(
        JsonRpcCode.invalidParams,
        'update_diary: categoryId "${e.categoryId}" is not a known category; '
        'call list_categories first',
      ),
      DiaryOpsFailure.noChanges => throw const JsonRpcException(
        JsonRpcCode.invalidParams,
        'update_diary: provide at least one field to change',
      ),
      _ => McpToolResult.error('update_diary: could not update the diary.'),
    };
  }
}

Future<McpToolResult> _createdOrUpdated(
  DiaryRepository diaries,
  CategoryRepository categories,
  Diary diary, {
  required bool created,
}) async {
  final names = await categoryNames(categories);
  return McpToolResult.json({
    'created': created,
    'updated': !created,
    ...diarySummary(diary, categoryName: names[diary.categoryId]),
    'uri': '$diaryUriPrefix${diary.id}',
  });
}

Future<McpToolResult> _deleteDiary(
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
}) async {
  final args = Args('delete_diary', arguments);
  final id = args.requireText('id');
  final mode =
      args.optionalEnum('mode', const ['delete', 'recycle']) ?? 'delete';
  final recycle = mode == 'recycle';

  try {
    final result = await DiaryWrites(diaries: diaries, categories: categories)
        .delete(
          id: id,
          mode: recycle ? DiaryDeleteMode.recycle : DiaryDeleteMode.permanent,
        );
    final title = result.diary.title.trim().isEmpty
        ? 'Untitled'
        : result.diary.title.trim();
    return McpToolResult.text(
      recycle
          ? 'delete_diary: moved "$title" (id=$id) to the recycle bin.'
          : 'delete_diary: deleted "$title" (id=$id) and its local media files.',
    );
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
  final categoryId = args.optionalText('categoryId');
  final start = args.optionalDate('start');
  final end = args.optionalDate('end', endOfDay: true);
  args.requireOrderedRange(start, end);
  final limit = args.optionalInt('limit', fallback: 20, min: 1, max: 100);
  final offset = args.optionalInt('offset', fallback: 0, min: 0, max: 1000000);
  final endExclusive = end?.add(const Duration(microseconds: 1));
  final renderMarkdown = args.optionalBool('renderMarkdown') ?? false;

  final page = await DiaryQueries(diaries: diaries).searchPage(
    query: query,
    categoryId: categoryId,
    start: start,
    endExclusive: endExclusive,
    limit: limit,
    offset: offset,
  );
  final names = await categoryNames(categories);
  call.reportProgress(
    page.hits.length,
    total: page.total,
    message: 'search_diaries',
  );
  return McpToolResult.json({
    'query': query,
    'total': page.total,
    'offset': offset,
    'limit': limit,
    'hasMore': offset + page.hits.length < page.total,
    'hits': [
      for (final hit in page.hits)
        {
          // The search snippet replaces `excerpt` below, so the summary keeps
          // its default plain projection and only `preview` follows
          // `renderMarkdown`.
          ...diarySummary(hit.diary, categoryName: names[hit.diary.categoryId]),
          'titleHighlight': _markHighlight(hit.titleHighlight),
          'excerpt': _markHighlight(hit.excerpt),
          'preview': excerptOf(hit.diary, renderMarkdown: renderMarkdown),
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
