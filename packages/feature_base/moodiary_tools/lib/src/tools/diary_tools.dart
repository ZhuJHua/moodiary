library;

import 'package:flutter/foundation.dart' show internal;
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import '../media/diary_media.dart';
import '../ops/diary_display.dart';
import '../ops/diary_queries.dart';
import '../ops/diary_writes.dart';
import 'arguments.dart';
import 'batch.dart';
import 'diary_payloads.dart';
import 'diary_queries.dart';
import 'diary_time.dart';
import 'diary_write_lock.dart';
import 'output_schemas.dart';
import 'schemas.dart';
import 'tool_def.dart';
import 'tool_values.dart';

@internal
final List<ToolDef> diaryTools = [
  ToolDef<_GetDiaryInput>(
    name: 'get_diary',
    title: 'Read diaries',
    description: (_) =>
        'Read diary bodies and metadata by ids (max 10). Pass every id you '
        'need in one call, using ids from search_diaries. Unknown or recycled '
        'ids are reported in missing. Markdown preserves media as ![name](src); '
        'keep these references when rewriting content. '
        'timeLocal gives the local date and time including hours and minutes. '
        'contentFormat selects markdown (default), text or the raw Tiptap '
        'document JSON. Bodies are capped at $assistantBodyChars characters '
        'in the assistant and $mcpResultChars in MCP; truncated and fullLength '
        'report any cap. document is subject to the same cap. Never rewrite '
        'from a truncated body; use append/prepend for additions. '
        'linkStyle=uri (default) preserves diary mention targets; label keeps '
        'only labels. includeLinks=true includes the graph of forward links, '
        'backlinks and dangling diary ids; it defaults to false. '
        'Attach files with add_diary_image or add_diary_attachment and inspect '
        'them with list_diary_media.',
    input: (_) => S.object(
      properties: {
        'ids': toolIdsSchema(diaryIdSchema, max: maxBatchRead),
        'contentFormat': readContentFormatSchema,
        'linkStyle': linkStyleSchema,
        'includeLinks': nullableSchema(
          schemaWithDefault(
            S.boolean(
              description:
                  'true includes links, the graph of forward links, backlinks and '
                  'dangling diary ids of this diary.',
            ),
            false,
          ),
          JsonType.boolean,
        ),
      },
      additionalProperties: false,
      required: ['ids'],
    ),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: _getDiaryOutput,
    parse: _parseGetDiary,
    run: _getDiaries,
  ),
  ToolDef(
    name: 'create_diary',
    title: 'Create a diary',
    description: (_) =>
        '$toolBatchDescription'
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
    input: (_) => batchItemsSchema(
      S.object(
        properties: {
          'title': nullableSchema(
            S.string(description: 'Diary title; may be empty.'),
            JsonType.string,
          ),
          'content': S.string(
            description:
                'Diary body; required. Interpreted according to contentFormat.',
          ),
          'contentFormat': writeContentFormatSchema,
          'time': diaryTimeSchema,
          'categoryId': categoryIdSchema,
          'mood': moodSchema,
          'tags': tagsSchema,
        },
        required: ['content'],
      ),
    ),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.write,
    idempotent: false,
    output: _createDiaryOutput,
    parse: toolBatchItems,
    run: (items, ctx) async {
      final names = await categoryNames(ctx.categories);
      return runToolBatch(
        items,
        (item) =>
            _createDiary(_parseCreateDiary(item, now: ctx.now()), ctx, names),
      );
    },
  ),
  ToolDef(
    name: 'update_diary',
    title: 'Update a diary',
    description: (_) =>
        '$toolBatchDescription'
        'Updates the given fields of each diary in the batch and leaves every omitted field '
        'unchanged; lastModified is bumped. Send null to clear a nullable '
        'field: categoryId, mood and tags (null or an empty array); '
        'title is cleared with an empty string. content and time are '
        'not nullable, so an explicit null for them is ignored. Prefer append '
        'and/or prepend (Markdown) for additions: they insert blocks and preserve '
        'the existing body and media. Legacy Markdown diaries keep Markdown; '
        'legacy rich-text diaries do not support append/prepend. Use content '
        'only for an intentional full rewrite; it cannot be combined with '
        'append or prepend. content '
        'replaces the whole body and contentFormat selects how it is '
        'interpreted (markdown default, text, or document for a Tiptap '
        'document JSON object). Media nodes in the body may only reference '
        'files this diary already owns (add new files with add_diary_image '
        'or add_diary_attachment); another diary\'s media name is invalid '
        'params. Rewrites must preserve every owned media reference from '
        'get_diary as ![name](src), unless its stored file name is explicitly '
        'listed in removeMedia. Unknown removeMedia names fail the item; '
        'removeMedia requires content. Bodies longer than the surface read cap '
        'cannot be rewritten; use append/prepend. '
        'Recycled diaries are not found. An unknown category id is '
        'an item error; an unknown diary id also fails only that item.',
    input: (_) => batchItemsSchema(
      S.object(
        properties: {
          'id': diaryIdSchema,
          'title': nullableSchema(
            S.string(description: 'New title; an empty string clears it.'),
            JsonType.string,
          ),
          'content': nullableSchema(
            S.string(
              description:
                  'Full body replacement only; prefer append/prepend for additions. '
                  'Interpreted according to contentFormat. Preserve owned media '
                  'as ![name](src), or explicitly allow dropping it in removeMedia.',
            ),
            JsonType.string,
          ),
          'append': nullableSchema(
            S.string(
              description: 'Markdown blocks to add after the existing body. Cannot be combined with content.',
            ),
            JsonType.string,
          ),
          'prepend': nullableSchema(
            S.string(
              description: 'Markdown blocks to add before the existing body. Cannot be combined with content.',
            ),
            JsonType.string,
          ),
          'removeMedia': nullableSchema(
            S.list(
              items: S.string(),
              description: 'Owned media file names explicitly allowed to disappear in a content rewrite. Requires content; unknown names fail.',
            ),
            JsonType.list,
          ),
          'contentFormat': writeContentFormatSchema,
          'time': diaryTimeSchema,
          'categoryId': categoryIdSchema,
          'mood': moodSchema,
          'tags': tagsSchema,
        },
        required: ['id'],
      ),
    ),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.destructive,
    tierOf: _updateDiaryTier,
    idempotent: false,
    output: _updateDiaryOutput,
    parse: toolBatchItems,
    run: (items, ctx) async {
      final names = await categoryNames(ctx.categories);
      return runToolBatch(
        items,
        (item) => _updateDiary(
          _parseUpdateDiary(item, maxRewriteChars: ctx.bodyChars),
          ctx,
          names,
        ),
      );
    },
  ),
  ToolDef(
    name: 'delete_diary',
    title: 'Delete a diary',
    description: (_) =>
        '$toolBatchDescription'
        'Moves each diary in the batch to the recycle bin (show=false). This can be undone '
        'in the app. Permanent deletion is only available in the app. title '
        'is the stored title, empty when the diary had none. An unknown id '
        'fails only that item.',
    input: (_) => S.object(
      properties: {'ids': toolIdsSchema(diaryIdSchema)},
      required: ['ids'],
    ),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.destructive,
    tierOf: (_) => ToolEffect.write,
    idempotent: true,
    output: _deleteDiaryOutput,
    parse: toolBatchIds,
    run: (items, ctx) => runToolBatch(
      items,
      (item) => _deleteDiary(
        ToolArguments('delete_diary', item).requireText('id'),
        ctx,
      ),
    ),
  ),
  ToolDef<_SearchDiariesInput>(
    name: 'search_diaries',
    title: 'Search diaries',
    description: (_) =>
        'Search or browse visible diaries. Omit query to browse by date, category '
        'or exact tag. Keyword terms combine with AND; prefer one or two specific '
        'words. Chinese text, pinyin and Latin text match. Results contain ids, '
        'titles, times, moods, categories, tags and excerpts; use get_diary for '
        'the full Markdown body before editing. Page with limit and offset. '
        'timeLocal gives the local date and time including hours and minutes. '
        'If total exceeds returned rows or totalIsLowerBound is true, say so '
        'instead of presenting the rows as the complete set. '
        'mode=auto fuses keyword and meaning search; keyword selects keywords, '
        'and meaning selects meaning search. Meaning search depends on the '
        'on-device semantic index; semanticAvailable: false means only keywords '
        'ran. Each hit reports via and similarity. When meaning search runs, '
        'each path uses a fixed window of 50 candidates; filters and sorting '
        'apply within that window before paging. Offsets beyond the combined '
        'results return no rows. '
        'Mood is ${toolMoodNames.join(', ')}; null means not recorded.',
    input: (_) => S.object(
      properties: {
        'query': nullableSchema(
          S.string(description: 'Keywords or a sentence; omit to browse.'),
          JsonType.string,
        ),
        'mode': nullableSchema(
          S.string(enumValues: diarySearchModeValues),
          JsonType.string,
        ),
        'tag': nullableSchema(S.string(), JsonType.string),
        'categoryId': categoryIdSchema,
        'startDate': startDateSchema,
        'endDate': endDateSchema,
        'sort': diarySearchSortSchema,
        'limit': limitSchema,
        'offset': offsetSchema,
        'excerpt': excerptSchema,
      },
      additionalProperties: false,
    ),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: _searchDiariesOutput,
    parse: _parseSearchDiaries,
    run: _searchDiaries,
  ),
  ToolDef<String>(
    name: 'get_diary_links',
    title: 'Read diary links',
    description: (_) =>
        'Lists the diaries this diary links to (forward), the diaries that '
        'link to it (backlinks) and the ids it mentions that do not exist '
        '(dangling), each with id, title and time. A dangling id is a '
        'moodiary://diary/<id> link to a diary that was deleted or never '
        'synced to this device.',
    input: (_) => S.object(properties: {'id': diaryIdSchema}, required: ['id']),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: _getDiaryLinksOutput,
    parse: (raw) => ToolArguments('get_diary_links', raw).requireText('id'),
    run: _getDiaryLinks,
  ),
  ToolDef<int>(
    name: 'list_tags',
    title: 'List tags',
    description: (_) =>
        'Lists the tags used by visible diaries with their usage counts, '
        'most used first.',
    input: (_) => S.object(properties: {'limit': tagLimitSchema}),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: _listTagsOutput,
    parse: (raw) =>
        ToolArguments('list_tags', raw).optionalInt('limit', tagLimit),
    run: _listTags,
  ),
];

ToolEffect _updateDiaryTier(Map<String, Object?> args) {
  final items = args['items'];
  final rewrites = switch (items) {
    List() => items.any((item) => item is Map && item.containsKey('content')),
    Map() => items.containsKey('content'),
    _ => args.containsKey('content'),
  };
  return rewrites ? ToolEffect.destructive : ToolEffect.write;
}

Future<void> _categoryFilter(
  String? id,
  String subject,
  CategoryRepository categories,
) async {
  if (id == null) return;
  if ((await categories.getCategoryById(id))?.deleted != false) {
    _unknownCategory(subject, id);
  }
}

Never _unknownCategory(
  String subject,
  String id,
) => throw ToolArgumentException(
  '$subject: categoryId "$id" is not a known category; call list_categories first',
);

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
    limit: args.optionalInt('limit', pageLimit),
    offset: args.optionalInt('offset', pageOffset),
  );
}

Future<Map<String, Tag>> _summaryTags(
  TagRepository tags,
  Iterable<Diary> diaries,
) async {
  final ids = diaries.expand((diary) => diary.tagIds).toSet();
  return ids.isEmpty ? {} : tags.getTagsByIds(ids);
}

Future<ToolResult> _mutation(
  Diary diary,
  Map<String, String> names,
  TagRepository tags,
) async => ToolResult({
  'diary': diarySummary(
    diary,
    tags: await _summaryTags(tags, [diary]),
    categoryName: names[diary.categoryId],
  ),
});

DiaryContentFormat _writeFormat(String? value) => switch (value) {
  'text' => DiaryContentFormat.plainText,
  'document' => DiaryContentFormat.document,
  _ => DiaryContentFormat.markdown,
};

Never _writeFailure(
  String subject,
  DiaryOpsException e,
  String id,
) => switch (e.failure) {
  DiaryOpsFailure.invalidCategory => _unknownCategory(subject, e.categoryId!),
  DiaryOpsFailure.invalidDocument => throw ToolArgumentException(
    '$subject: content is not a Tiptap document; contentFormat="document" '
    'expects a JSON object with type "doc"',
  ),
  DiaryOpsFailure.emptyContent => throw ToolArgumentException(
    '$subject: content must not be empty',
  ),
  DiaryOpsFailure.rewriteTooLong => throw ToolArgumentException(
    '$subject: the current body of id="$id" exceeds the ${e.maxRewriteChars} character read limit and may be truncated; '
    'it is too long to rewrite in one go. Use append/prepend for additions',
  ),
  DiaryOpsFailure.notFound => toolFailure('$subject: no diary with id="$id".'),
  DiaryOpsFailure.foreignMedia => throw ToolArgumentException(
    '$subject: content references media this diary does not own; add new '
    'files with add_diary_image or add_diary_attachment first',
  ),
  DiaryOpsFailure.conflictingBodyEdits => throw ToolArgumentException(
    '$subject: content cannot be combined with append or prepend; use '
    'append/prepend for additions or content for a full rewrite',
  ),
  DiaryOpsFailure.unsupportedBodyAddition => throw ToolArgumentException(
    '$subject: append/prepend is not supported for legacy rich-text diaries; '
    'edit this diary in the app',
  ),
  DiaryOpsFailure.missingMedia => throw ToolArgumentException(
    '$subject: content would drop owned media: ${e.mediaNames.join(', ')}. '
    'Keep their ![name](src) references from get_diary, or explicitly list '
    'the file names in removeMedia to drop them on purpose',
  ),
  DiaryOpsFailure.unknownMediaRemoval => throw ToolArgumentException(
    '$subject: removeMedia contains names this diary does not own: '
    '${e.mediaNames.join(', ')}',
  ),
  DiaryOpsFailure.mediaRemovalRequiresContent => throw ToolArgumentException(
    '$subject: removeMedia requires content; omit it for append/prepend '
    'or metadata changes',
  ),
  final failure => toolFailure(
    '$subject: the diary could not be written (${failure.name}).',
  ),
};

Future<ToolResult> _getDiaries(_GetDiaryInput input, ToolContext ctx) async {
  final read = await DiaryQueries(
    tags: ctx.tags,
    diaries: ctx.diaries,
  ).read(input.ids);
  final names = await categoryNames(ctx.categories);
  final results = <Map<String, Object?>>[];
  final tags = await _summaryTags(ctx.tags, read.found);
  for (final diary in read.found) {
    results.add(await _getDiaryPayload(diary, input, ctx, names, tags));
  }
  return ToolResult({'diaries': results, 'missing': read.missing});
}

Future<Map<String, Object?>> _getDiaryPayload(
  Diary diary,
  _GetDiaryInput input,
  ToolContext ctx,
  Map<String, String> names,
  Map<String, Tag> tags,
) async {
  final id = diary.id;
  final (:contentFormat, :linkStyle, :includeLinks, ids: _) = input;
  final projection = readBody(
    diary,
    ctx.bodyChars,
    contentFormat,
    linkStyle: linkStyle == 'label' ? DiaryLinkStyle.label : DiaryLinkStyle.uri,
  );
  if (contentFormat == 'document' && projection.truncated) {
    toolFailure(
      'get_diary: the stored document of id="$id" is '
      '${projection.fullLength} characters, more than the ${ctx.bodyChars} '
      'character result limit; read it as text (contentFormat="text") or as Markdown instead.',
    );
  }
  return {
    ...diarySummary(diary, tags: tags, categoryName: names[diary.categoryId]),
    'type': diary.type,
    'contentFormat': contentFormat,
    'content': projection.content,
    'truncated': projection.truncated,
    'fullLength': projection.fullLength,
    'placeId': diary.placeId,
    if (diary.weather case final weather?)
      'weather': {
        'icon': weather.icon,
        'temp': weather.temp,
        'text': weather.text,
      },
    'media': mediaLists(diary),
    if (includeLinks ?? ctx.includeLinks)
      'links': await DiaryToolQueries(
        tags: ctx.tags,
        diaries: ctx.diaries,
      ).linkSummary(diary),
    'uri': '$diaryUriPrefix${diary.id}',
  };
}

Future<ToolResult> _createDiary(
  _CreateDiaryInput input,
  ToolContext ctx,
  Map<String, String> names,
) async {
  final (:content, :contentFormat, :title, :time, :mood, :tags, :categoryId) =
      input;
  final Diary diary;
  try {
    diary =
        await DiaryWrites(
          tags: ctx.tags,
          diaries: ctx.diaries,
          categories: ctx.categories,
        ).create(
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
    _writeFailure('create_diary', e, '');
  }
  return _mutation(diary, names, ctx.tags);
}

Future<ToolResult> _updateDiary(
  _UpdateDiaryInput input,
  ToolContext ctx,
  Map<String, String> names,
) async {
  final (:id, :patch, :contentFormat) = input;
  try {
    return await withDiaryWriteLock(id, () async {
      final next =
          await DiaryWrites(
            tags: ctx.tags,
            diaries: ctx.diaries,
            categories: ctx.categories,
          ).update(
            id: id,
            patch: patch,
            format: contentFormat,
            enforceOwnMedia: true,
          );
      return _mutation(next, names, ctx.tags);
    });
  } on DiaryOpsException catch (e) {
    _writeFailure('update_diary', e, id);
  }
}

Future<ToolResult> _deleteDiary(String id, ToolContext ctx) async {
  return withDiaryWriteLock(id, () async {
    try {
      final result = await DiaryWrites(
        tags: ctx.tags,
        diaries: ctx.diaries,
        categories: ctx.categories,
      ).delete(id: id);
      return ToolResult({
        'id': id,
        'title': result.diary.title.trim(),
        if (result.outcome == DiaryDeleteOutcome.alreadyRecycled)
          'alreadyRecycled': true,
      });
    } on DiaryOpsException {
      toolFailure('delete_diary: no diary with id="$id".');
    }
  });
}

Future<ToolResult> _searchDiaries(
  _SearchDiariesInput input,
  ToolContext ctx,
) async {
  final (:query, :mode, :tag, :paging, :sort, :excerpt) = input;
  await _categoryFilter(paging.categoryId, 'search_diaries', ctx.categories);
  final result =
      await DiaryQueries(
        tags: ctx.tags,
        diaries: ctx.diaries,
        semantic: ctx.semantic,
      ).search(
        query: query,
        mode: mode,
        tag: tag,
        categoryId: paging.categoryId,
        start: paging.start,
        endExclusive: paging.end?.add(const Duration(microseconds: 1)),
        sort: sort,
        limit: paging.limit,
        offset: paging.offset,
      );
  final names = await categoryNames(ctx.categories);
  final tags = await _summaryTags(
    ctx.tags,
    result.rows.map((row) => row.diary),
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
    'meaningRan': result.meaningRan,
    'semanticAvailable': result.semanticAvailable,
    'hits': [
      for (final row in result.rows)
        {
          ...diarySummary(
            row.diary,
            tags: tags,
            categoryName: names[row.diary.categoryId],
            renderMarkdown: excerpt == 'markdown',
            includeExcerpt: excerpt != 'none',
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
          'via': row.keyword && row.meaning
              ? 'keyword+meaning'
              : row.meaning
              ? 'meaning'
              : 'keyword',
          'similarity': row.score,
        },
    ],
  });
}

String _markHighlight(String text) =>
    text.replaceAll(searchHitStart, '**').replaceAll(searchHitEnd, '**');

Future<ToolResult> _getDiaryLinks(String id, ToolContext ctx) async {
  final diary = await ctx.diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    toolFailure('get_diary_links: no diary with id="$id".');
  }
  final links = await DiaryToolQueries(
    tags: ctx.tags,
    diaries: ctx.diaries,
  ).linkSummary(diary);
  return ToolResult({...linkRow(diary), ...links});
}

Future<ToolResult> _listTags(int limit, ToolContext ctx) async {
  final result = await DiaryToolQueries(
    tags: ctx.tags,
    diaries: ctx.diaries,
  ).tags(limit: limit);
  return ToolResult({
    'tags': [
      for (final entry in result.tags)
        {'tag': entry.tag, 'diaries': entry.diaries},
    ],
    'count': result.tags.length,
    'totalDistinct': result.totalDistinct,
    'scannedDiaries': result.scannedDiaries,
    'note': 'Counts include visible diaries only.',
  });
}

typedef _GetDiaryInput = ({
  List<String> ids,
  String contentFormat,
  String linkStyle,
  bool? includeLinks,
});

_GetDiaryInput _parseGetDiary(Map<String, Object?> raw) {
  final args = ToolArguments('get_diary', raw);
  final ids = (raw['ids']! as List).cast<String>();
  final contentFormat = args.optionalText('contentFormat') ?? 'markdown';
  final linkStyle = args.optionalText('linkStyle') ?? 'uri';
  final includeLinks = args.optionalBool('includeLinks');

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

_CreateDiaryInput _parseCreateDiary(
  Map<String, Object?> raw, {
  required DateTime now,
}) {
  final args = ToolArguments('create_diary', raw);
  final content = args.requireText('content');
  final contentFormat = _writeFormat(args.optionalText('contentFormat'));
  final title = args.optionalText('title') ?? '';
  final time = resolveDiaryTime(
    raw['time'],
    reference: now,
    subject: 'create_diary',
  );
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

_UpdateDiaryInput _parseUpdateDiary(
  Map<String, Object?> raw, {
  required int maxRewriteChars,
}) {
  final args = ToolArguments('update_diary', raw);
  final id = args.requireText('id');
  final contentFormat = _writeFormat(args.optionalText('contentFormat'));
  final patch = DiaryPatch(
    title: args.contains('title') ? args.text('title') : null,
    content: args.contains('content') ? args.requireText('content') : null,
    append: args.contains('append') ? args.requireText('append') : null,
    prepend: args.contains('prepend') ? args.requireText('prepend') : null,
    removeMedia: args.optionalStringList('removeMedia') ?? const [],
    mood: args.has('mood') ? args.optionalMood('mood') : null,
    moodSet: args.has('mood'),
    categoryId: args.has('categoryId')
        ? (args.optionalText('categoryId') ?? '')
        : null,
    timeInput: args.contains('time') ? args.text('time') : null,
    maxRewriteChars: maxRewriteChars,
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
    mode: args.optionalText('mode') ?? 'auto',
    tag: args.optionalText('tag'),
    paging: _pageArgs(args),
    sort: args.optionalText('sort'),
    excerpt: args.optionalText('excerpt') ?? 'plain',
  );
}

final _getDiaryOutput = objectSchema({
  'diaries': listOutputSchema(
    objectSchema(
      {
        ...diarySummaryFields,
        'type': stringOutputSchema,
        'contentFormat': stringOutputSchema,
        'content': S.combined(type: [JsonType.string, JsonType.object]),
        'truncated': booleanOutputSchema,
        'fullLength': integerOutputSchema,
        'placeId': nullableStringOutputSchema,
        'weather': objectSchema({
          'icon': stringOutputSchema,
          'temp': nullableStringOutputSchema,
          'text': stringOutputSchema,
        }),
        'media': mediaListsOutputSchema,
        'links': linksOutputSchema,
        'uri': stringOutputSchema,
      },
      optional: ['excerpt', 'weather', 'links'],
    ),
  ),
  'missing': listOutputSchema(stringOutputSchema),
});

final _createDiaryOutput = batchOutputSchema(
  objectSchema({'diary': diarySummarySchema}),
);

final _updateDiaryOutput = batchOutputSchema(
  objectSchema({'diary': diarySummarySchema}),
);

final _deleteDiaryOutput = batchOutputSchema(
  objectSchema(
    {
      'id': stringOutputSchema,
      'title': stringOutputSchema,
      'alreadyRecycled': booleanOutputSchema,
    },
    optional: ['alreadyRecycled'],
  ),
);

final _searchDiariesOutput = objectSchema(
  {
    'query': stringOutputSchema,
    'total': integerOutputSchema,
    'totalIsLowerBound': booleanOutputSchema,
    'offset': integerOutputSchema,
    'limit': integerOutputSchema,
    'hasMore': booleanOutputSchema,
    'meaningRan': booleanOutputSchema,
    'semanticAvailable': booleanOutputSchema,
    'hits': listOutputSchema(
      objectSchema(
        {
          ...diarySummaryFields,
          'titleHighlight': stringOutputSchema,
          'preview': stringOutputSchema,
          'via': stringOutputSchema,
          'similarity': S.combined(type: [JsonType.num, JsonType.nil]),
        },
        optional: ['excerpt', 'titleHighlight', 'preview', 'via', 'similarity'],
      ),
    ),
  },
  optional: ['meaningRan', 'semanticAvailable'],
);

final _getDiaryLinksOutput = objectSchema({
  ...linkOutputSchema.properties!,
  ...linksOutputSchema.properties!,
});

final _listTagsOutput = objectSchema({
  'tags': listOutputSchema(
    objectSchema({'tag': stringOutputSchema, 'diaries': integerOutputSchema}),
  ),
  'count': integerOutputSchema,
  'totalDistinct': integerOutputSchema,
  'scannedDiaries': integerOutputSchema,
  'note': stringOutputSchema,
});
