import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_mcp/src/protocol/json_rpc.dart';
import 'package:moodiary_mcp/src/protocol/mcp_types.dart';
import 'package:moodiary_mcp/src/server/mcp_server.dart';
import 'package:moodiary_mcp/src/server/mcp_session.dart';
import 'package:moodiary_mcp/src/tools/register_moodiary_tools.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

Diary makeDiary(
  String id,
  String text, {
  String? content,
  String? title,
  List<String> linkTo = const [],
  List<String> tags = const [],
  DateTime? time,
  String? categoryId,
  bool show = true,
}) {
  final doc =
      content ??
      jsonEncode({
        'type': 'doc',
        'attrs': {'v': 2},
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': text},
              for (final target in linkTo)
                {
                  'type': 'diaryLink',
                  'attrs': {'id': target, 'label': 'L'},
                },
            ],
          },
        ],
      });
  return Diary(
    id: id,
    categoryId: categoryId,
    title: title ?? 'title-$id',
    content: doc,
    contentText: text,
    time: time ?? DateTime.utc(2026, 1, 1),
    lastModified: time ?? DateTime.utc(2026, 1, 1),
    show: show,
    mood: null,
    imageName: const [],
    audioName: const [],
    videoName: const [],
    tags: tags,
    type: 'tiptap',
  );
}

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository diaries;
  late CategoryRepository categories;
  late MoodInsightsRepository insights;
  late McpServer server;
  late McpSessionState session;
  var seq = 0;

  setUpAll(() {
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
  });

  setUp(() {
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    diaries = DiaryRepository(db);
    categories = CategoryRepository(db);
    insights = MoodInsightsRepository(db);
    server = McpServer(
      registry: buildMoodiaryRegistry(
        diaries: diaries,
        categories: categories,
        insights: insights,
        appVersion: 'test',
      ),
      serverVersion: 'test',
    );
    session = server.createSession();
    seq = 0;
  });

  tearDown(() async {
    server.dispose();
    await db.close();
  });

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    final response = await server.handle(session, {
      'jsonrpc': '2.0',
      'id': ++seq,
      'method': method,
      'params': params,
    });
    expect(response, isNotNull, reason: '$method must answer a request');
    return response!;
  }

  Future<Map<String, dynamic>> toolCall(
    String name, [
    Map<String, dynamic> arguments = const {},
  ]) => call('tools/call', {'name': name, 'arguments': arguments});

  Map<String, dynamic> resultOf(Map<String, dynamic> response) =>
      response['result'] as Map<String, dynamic>;

  Map<String, dynamic> structuredOf(Map<String, dynamic> response) =>
      resultOf(response)['structuredContent'] as Map<String, dynamic>;

  String textOf(Map<String, dynamic> response) {
    final content = resultOf(response)['content'] as List;
    return (content.single as Map)['text'] as String;
  }

  int errorCode(Map<String, dynamic> response) =>
      (response['error'] as Map)['code'] as int;

  String resourceText(Map<String, dynamic> response) {
    final contents = resultOf(response)['contents'] as List;
    return (contents.single as Map)['text'] as String;
  }

  Map<String, dynamic> resourceJson(Map<String, dynamic> response) =>
      jsonDecode(resourceText(response)) as Map<String, dynamic>;

  List<String> completionValues(Map<String, dynamic> response) {
    final completion = resultOf(response)['completion'] as Map;
    return (completion['values'] as List).cast<String>();
  }

  List<String> diaryIds(Map<String, dynamic> data) => [
    for (final diary in data['diaries'] as List)
      (diary as Map<String, dynamic>)['id'] as String,
  ];

  Map<String, dynamic> singleSummary(Map<String, dynamic> data) =>
      (data['diaries'] as List).cast<Map<String, dynamic>>().single;

  Map<String, dynamic> storedDoc(String content) =>
      jsonDecode(content) as Map<String, dynamic>;

  List<Map<String, dynamic>> docBlocks(Map<String, dynamic> doc) =>
      (doc['content'] as List).cast<Map<String, dynamic>>();

  Future<String> newCategory(String name, {String? parentId}) async {
    final created = structuredOf(
      await toolCall('create_category', {'name': name, 'parentId': ?parentId}),
    );
    expect(created['created'], isTrue);
    return created['id'] as String;
  }

  group('catalog', () {
    test('initialize then tools/list returns the full catalog', () async {
      final initialized = resultOf(
        await call('initialize', {'protocolVersion': mcpLatestProtocolVersion}),
      );
      expect(initialized['protocolVersion'], mcpLatestProtocolVersion);
      expect((initialized['serverInfo'] as Map)['version'], 'test');

      final listed = resultOf(await call('tools/list'));
      final tools = (listed['tools'] as List).cast<Map<String, dynamic>>();
      expect(
        {for (final tool in tools) tool['name']},
        {
          'list_diaries',
          'get_diary',
          'create_diary',
          'update_diary',
          'delete_diary',
          'search_diaries',
          'get_diary_links',
          'list_tags',
          'list_categories',
          'create_category',
          'update_category',
          'delete_category',
          'get_stats',
          'server_info',
        },
      );
      for (final tool in tools) {
        expect(
          (tool['description'] as String).trim(),
          isNotEmpty,
          reason: '${tool['name']} needs a description',
        );
        final schema = tool['inputSchema'] as Map;
        expect(schema['type'], 'object', reason: '${tool['name']} schema');
      }
    });
  });

  group('diary tools', () {
    test('create_diary and get_diary round-trip metadata and body', () async {
      final categoryId = await newCategory('Journal');
      final created = structuredOf(
        await toolCall('create_diary', {
          'title': 'Morning note',
          'content': 'apple pie and coffee',
          'time': '2026-01-15T08:30:00Z',
          'categoryId': categoryId,
          'mood': 'good',
          'tags': ['food', 'morning'],
        }),
      );
      expect(created['created'], isTrue);
      expect(created['updated'], isFalse);
      final id = created['id'] as String;
      expect(created['title'], 'Morning note');
      expect(created['time'], '2026-01-15T08:30:00.000Z');
      expect(created['categoryId'], categoryId);
      expect(created['categoryName'], 'Journal');
      expect(created['mood'], 'good');
      expect(created['tags'], ['food', 'morning']);
      expect(created['show'], isTrue);

      final stored = await diaries.getDiaryByBusinessId(id);
      expect(stored, isNotNull);
      expect(stored!.contentText, 'apple pie and coffee');

      final read = structuredOf(
        await toolCall('get_diary', {'id': id, 'format': 'markdown'}),
      );
      expect(read['id'], id);
      expect(read['title'], 'Morning note');
      expect(read['contentFormat'], 'markdown');
      expect(read['content'], 'apple pie and coffee');
      expect(read['contentTruncated'], isFalse);
      expect(read['categoryId'], categoryId);
      expect(read['mood'], 'good');
      expect(read['tags'], ['food', 'morning']);
      expect(read['time'], '2026-01-15T08:30:00.000Z');
      expect((read['media'] as Map)['images'], isEmpty);
    });

    test(
      'update_diary changes only given fields and bumps lastModified',
      () async {
        await diaries.insertADiary(
          makeDiary(
            'update-me',
            'old body',
            title: 'Before',
            tags: ['keep'],
            time: DateTime.utc(2000, 1, 1),
          ),
        );
        final before = (await diaries.getDiaryByBusinessId('update-me'))!;

        final updated = structuredOf(
          await toolCall('update_diary', {'id': 'update-me', 'title': 'After'}),
        );
        expect(updated['updated'], isTrue);
        expect(updated['created'], isFalse);
        expect(updated['title'], 'After');
        expect(updated['tags'], ['keep']);
        expect(updated['time'], '2000-01-01T00:00:00.000Z');

        var after = (await diaries.getDiaryByBusinessId('update-me'))!;
        expect(after.title, 'After');
        expect(after.contentText, 'old body');
        expect(after.tags, ['keep']);
        expect(after.time, before.time);
        expect(after.lastModified.isAfter(before.lastModified), isTrue);

        await toolCall('update_diary', {
          'id': 'update-me',
          'content': 'new body',
        });
        after = (await diaries.getDiaryByBusinessId('update-me'))!;
        expect(after.title, 'After');
        expect(after.contentText, 'new body');
        expect(after.lastModified.isAfter(before.lastModified), isTrue);

        final read = structuredOf(
          await toolCall('get_diary', {
            'id': 'update-me',
            'format': 'markdown',
          }),
        );
        expect(read['content'], 'new body');
      },
    );

    test('delete_diary recycles, restores and permanently deletes', () async {
      await diaries.insertDiaries([
        makeDiary('recycle-me', 'recycle body', title: 'Recycle'),
        makeDiary('delete-me', 'delete body', title: 'Delete'),
      ]);

      final recycled = await toolCall('delete_diary', {
        'id': 'recycle-me',
        'mode': 'recycle',
      });
      expect(resultOf(recycled)['isError'], isFalse);
      expect(textOf(recycled), contains('recycle bin'));
      expect((await diaries.getDiaryByBusinessId('recycle-me'))!.show, isFalse);

      final restored = structuredOf(
        await toolCall('update_diary', {'id': 'recycle-me', 'show': true}),
      );
      expect(restored['show'], isTrue);
      expect((await diaries.getDiaryByBusinessId('recycle-me'))!.show, isTrue);

      final deleted = await toolCall('delete_diary', {'id': 'delete-me'});
      expect(resultOf(deleted)['isError'], isFalse);
      expect(textOf(deleted), contains('deleted'));
      expect(await diaries.getDiaryByBusinessId('delete-me'), isNull);
    });

    test('search_diaries finds body words and handles no hits', () async {
      await diaries.insertDiaries([
        makeDiary('apple', 'apple pie recipe', title: 'Food'),
        makeDiary('banana', 'banana bread recipe', title: 'Baking'),
      ]);

      final found = structuredOf(
        await toolCall('search_diaries', {'query': 'apple'}),
      );
      expect(found['total'], 1);
      final hits = (found['hits'] as List).cast<Map<String, dynamic>>();
      expect(hits, hasLength(1));
      expect(hits.single['id'], 'apple');
      expect(hits.single['excerpt'] as String, contains('**apple**'));

      final missing = structuredOf(
        await toolCall('search_diaries', {'query': 'zzzz'}),
      );
      expect(missing['total'], 0);
      expect(missing['hits'], isEmpty);
    });

    test(
      'list_diaries pages, sorts and filters by category and time',
      () async {
        final categoryId = await newCategory('Logs');
        for (var day = 1; day <= 5; day++) {
          await diaries.insertADiary(
            makeDiary(
              'd$day',
              'entry $day',
              categoryId: day <= 2 ? categoryId : null,
              time: DateTime(2026, 1, day, 12),
            ),
          );
        }

        final page = structuredOf(
          await toolCall('list_diaries', {
            'limit': 2,
            'offset': 1,
            'sort': 'timeDesc',
          }),
        );
        expect(diaryIds(page), ['d4', 'd3']);
        expect(page['count'], 2);
        expect(page['hasMore'], isTrue);

        final ascending = structuredOf(
          await toolCall('list_diaries', {'limit': 3, 'sort': 'timeAsc'}),
        );
        expect(diaryIds(ascending), ['d1', 'd2', 'd3']);

        final byCategory = structuredOf(
          await toolCall('list_diaries', {'categoryId': categoryId}),
        );
        expect(diaryIds(byCategory), ['d2', 'd1']);
        expect([
          for (final diary
              in (byCategory['diaries'] as List).cast<Map<String, dynamic>>())
            diary['categoryId'],
        ], everyElement(categoryId));

        final byWindow = structuredOf(
          await toolCall('list_diaries', {
            'start': '2026-01-02',
            'end': '2026-01-04',
            'sort': 'timeAsc',
          }),
        );
        expect(diaryIds(byWindow), ['d2', 'd3', 'd4']);
      },
    );
  });

  group('rendering and content format arguments', () {
    test(
      'get_diary renderLinks=false keeps the label and drops the URI',
      () async {
        await diaries.insertDiaries([
          makeDiary('target', 'target body'),
          makeDiary('source', 'see ', linkTo: ['target']),
        ]);

        final withLinks = structuredOf(
          await toolCall('get_diary', {'id': 'source'}),
        );
        expect(withLinks['contentFormat'], 'markdown');
        expect(withLinks['content'], contains('[L](moodiary://diary/target)'));

        final labelOnly = structuredOf(
          await toolCall('get_diary', {'id': 'source', 'renderLinks': false}),
        );
        expect(labelOnly['content'], 'see L');
        expect(labelOnly['content'], isNot(contains('moodiary://diary/')));
      },
    );

    test('get_diary renderMarkdown=false returns the plain body', () async {
      final doc = jsonEncode({
        'type': 'doc',
        'attrs': {'v': 2},
        'content': [
          {
            'type': 'heading',
            'attrs': {'level': 1},
            'content': [
              {'type': 'text', 'text': 'Heading'},
            ],
          },
          {
            'type': 'paragraph',
            'content': [
              {
                'type': 'text',
                'text': 'bold words',
                'marks': [
                  {'type': 'bold'},
                ],
              },
            ],
          },
        ],
      });
      await diaries.insertADiary(
        makeDiary('rich', 'Heading\nbold words', content: doc),
      );

      final markdown = structuredOf(
        await toolCall('get_diary', {'id': 'rich'}),
      );
      expect(markdown['contentFormat'], 'markdown');
      expect(markdown['content'], contains('# Heading'));
      expect(markdown['content'], contains('**bold words**'));

      final plain = structuredOf(
        await toolCall('get_diary', {'id': 'rich', 'renderMarkdown': false}),
      );
      expect(plain['contentFormat'], 'text');
      expect(plain['content'], 'Heading\nbold words');
      expect(plain['content'], isNot(contains('**')));
      expect(plain['content'], isNot(contains('#')));

      // An explicit raw format still wins over renderMarkdown.
      final raw = structuredOf(
        await toolCall('get_diary', {
          'id': 'rich',
          'format': 'tiptap',
          'renderMarkdown': false,
        }),
      );
      expect(raw['contentFormat'], 'tiptap');
      expect(raw['content'], isA<Map>());
    });

    test(
      'list_diaries renderMarkdown=true returns a Markdown excerpt',
      () async {
        final doc = jsonEncode({
          'type': 'doc',
          'attrs': {'v': 2},
          'content': [
            {
              'type': 'heading',
              'attrs': {'level': 2},
              'content': [
                {'type': 'text', 'text': 'Plan'},
              ],
            },
            {
              'type': 'paragraph',
              'content': [
                {'type': 'text', 'text': 'body text'},
              ],
            },
          ],
        });
        await diaries.insertADiary(
          makeDiary('md', 'Plan\nbody text', content: doc),
        );

        final plain = structuredOf(await toolCall('list_diaries'));
        expect(singleSummary(plain)['excerpt'], 'Plan body text');

        final marked = structuredOf(
          await toolCall('list_diaries', {'renderMarkdown': true}),
        );
        final excerpt = singleSummary(marked)['excerpt'] as String;
        expect(excerpt, contains('## Plan'));
        expect(excerpt, contains('body text'));
      },
    );

    test(
      'search_diaries renderMarkdown=true returns a Markdown preview',
      () async {
        final doc = jsonEncode({
          'type': 'doc',
          'attrs': {'v': 2},
          'content': [
            {
              'type': 'heading',
              'attrs': {'level': 2},
              'content': [
                {'type': 'text', 'text': 'apple'},
              ],
            },
            {
              'type': 'paragraph',
              'content': [
                {'type': 'text', 'text': 'note'},
              ],
            },
          ],
        });
        await diaries.insertADiary(
          makeDiary('apple-doc', 'apple\nnote', content: doc),
        );

        final plain = structuredOf(
          await toolCall('search_diaries', {'query': 'apple'}),
        );
        final plainHit = (plain['hits'] as List)
            .cast<Map<String, dynamic>>()
            .single;
        expect(plainHit['preview'], 'apple note');
        expect(plainHit['excerpt'], contains('**apple**'));

        final marked = structuredOf(
          await toolCall('search_diaries', {
            'query': 'apple',
            'renderMarkdown': true,
          }),
        );
        final markedHit = (marked['hits'] as List)
            .cast<Map<String, dynamic>>()
            .single;
        expect(markedHit['preview'], contains('## apple'));
        expect(markedHit['excerpt'], contains('**apple**'));
      },
    );

    test('create_diary contentFormat picks Markdown or plain text', () async {
      final markdown = structuredOf(
        await toolCall('create_diary', {
          'title': 'Markdown',
          'content': '# Heading\n\n- one\n- two',
        }),
      );
      final markdownStored = (await diaries.getDiaryByBusinessId(
        markdown['id'] as String,
      ))!;
      expect(markdownStored.type, 'tiptap');
      final markdownTypes = docBlocks(storedDoc(markdownStored.content))
          .map((block) => block['type']);
      expect(markdownTypes, contains('heading'));
      expect(markdownTypes, contains('bulletList'));

      final markdownRead = structuredOf(
        await toolCall('get_diary', {'id': markdown['id']}),
      );
      expect(markdownRead['content'], contains('# Heading'));
      expect(markdownRead['content'], contains('- one'));

      final text = structuredOf(
        await toolCall('create_diary', {
          'title': 'Text',
          'content': '# Heading',
          'contentFormat': 'text',
        }),
      );
      final textStored = (await diaries.getDiaryByBusinessId(
        text['id'] as String,
      ))!;
      final textBlocks = docBlocks(storedDoc(textStored.content));
      expect(textBlocks, hasLength(1));
      expect(textBlocks.single['type'], 'paragraph');
      expect(textStored.contentText, '# Heading');
    });

    test('update_diary contentFormat rewrites the body the same way', () async {
      await diaries.insertADiary(makeDiary('edit', 'start'));

      await toolCall('update_diary', {'id': 'edit', 'content': '## Later'});
      var stored = (await diaries.getDiaryByBusinessId('edit'))!;
      expect(docBlocks(storedDoc(stored.content)).single['type'], 'heading');

      await toolCall('update_diary', {
        'id': 'edit',
        'content': '## Later',
        'contentFormat': 'text',
      });
      stored = (await diaries.getDiaryByBusinessId('edit'))!;
      final blocks = docBlocks(storedDoc(stored.content));
      expect(blocks.single['type'], 'paragraph');
      expect(
        ((blocks.single['content'] as List).single as Map)['text'],
        '## Later',
      );
      expect(stored.contentText, '## Later');
    });
  });

  group('categories and statistics', () {
    test(
      'category tools build a tree, rename and refuse non-empty delete',
      () async {
        final parent = await newCategory('Work');
        final child = await newCategory('Projects', parentId: parent);
        final empty = await newCategory('Temp');

        var listed = structuredOf(await toolCall('list_categories'));
        expect(listed['total'], 3);
        final roots = (listed['categories'] as List)
            .cast<Map<String, dynamic>>();
        final parentNode = roots.firstWhere((node) => node['id'] == parent);
        expect(parentNode['parentId'], isNull);
        final children = (parentNode['children'] as List)
            .cast<Map<String, dynamic>>();
        expect(children, hasLength(1));
        expect(children.single['id'], child);
        expect(children.single['parentId'], parent);

        final renamed = structuredOf(
          await toolCall('update_category', {
            'id': child,
            'name': 'Projects 2026',
          }),
        );
        expect(renamed['updated'], isTrue);
        expect(renamed['name'], 'Projects 2026');

        listed = structuredOf(await toolCall('list_categories'));
        final renamedNode =
            ((listed['categories'] as List)
                        .cast<Map<String, dynamic>>()
                        .firstWhere((node) => node['id'] == parent)['children']
                    as List)
                .cast<Map<String, dynamic>>()
                .single;
        expect(renamedNode['name'], 'Projects 2026');

        final removed = structuredOf(
          await toolCall('delete_category', {'id': empty}),
        );
        expect(removed['deleted'], isTrue);
        expect(removed['id'], empty);
        expect(await categories.getCategoryById(empty), isNull);

        await diaries.insertADiary(
          makeDiary('busy-diary', 'stays', categoryId: child),
        );
        final refused = structuredOf(
          await toolCall('delete_category', {'id': child}),
        );
        expect(refused['deleted'], isFalse);
        expect(refused['id'], child);
        expect(refused['reason'] as String, isNotEmpty);
        expect(await categories.getCategoryById(child), isNotNull);
      },
    );

    test('get_stats reports totals and per-category counts', () async {
      final work = await newCategory('Work');
      final life = await newCategory('Life');
      await diaries.insertDiaries([
        makeDiary('w1', 'one', categoryId: work),
        makeDiary('l1', 'two', categoryId: life),
        makeDiary('l2', 'three', categoryId: life),
        makeDiary('hidden', 'four', categoryId: work, show: false),
      ]);

      final stats = structuredOf(await toolCall('get_stats'));
      expect(stats['totalDiaries'], 4);
      expect(stats['visibleDiaries'], 3);
      expect(stats['recycleBinDiaries'], 1);
      expect(stats['uncategorizedDiaries'], 0);
      final rows = {
        for (final row
            in (stats['categories'] as List).cast<Map<String, dynamic>>())
          row['categoryId'] as String: row['diaries'] as int,
      };
      expect(rows[work], 1);
      expect(rows[life], 2);
    });

    test('list_tags aggregates tags over visible diaries', () async {
      await diaries.insertDiaries([
        makeDiary('a', 'a', tags: ['travel', 'food']),
        makeDiary('b', 'b', tags: ['travel']),
        makeDiary('c', 'c', tags: ['travel'], show: false),
      ]);

      final tags = structuredOf(await toolCall('list_tags'));
      final rows = {
        for (final row in (tags['tags'] as List).cast<Map<String, dynamic>>())
          row['tag'] as String: row['diaries'] as int,
      };
      expect(rows, {'travel': 2, 'food': 1});
      expect(tags['count'], 2);
      expect(tags['totalDistinct'], 2);
      expect(tags['scannedDiaries'], 2);
      expect((tags['tags'] as List).first, {'tag': 'travel', 'diaries': 2});
    });
  });

  group('links', () {
    test('get_diary_links reports forward links and backlinks', () async {
      await diaries.insertDiaries([
        makeDiary('target', 'target body'),
        makeDiary('source-a', 'source a', linkTo: ['target']),
        makeDiary('source-b', 'source b', linkTo: ['target']),
      ]);

      final forward = structuredOf(
        await toolCall('get_diary_links', {'id': 'source-a'}),
      );
      expect(forward['id'], 'source-a');
      expect(
        [
          for (final link
              in (forward['forward'] as List).cast<Map<String, dynamic>>())
            link['id'],
        ],
        ['target'],
      );
      expect(forward['backlinks'], isEmpty);

      final back = structuredOf(
        await toolCall('get_diary_links', {'id': 'target'}),
      );
      expect(
        {
          for (final link
              in (back['backlinks'] as List).cast<Map<String, dynamic>>())
            link['id'],
        },
        {'source-a', 'source-b'},
      );
      expect(back['forward'], isEmpty);
    });
  });

  group('resources', () {
    test('resources expose the catalog and one diary', () async {
      final categoryId = await newCategory('Resource category');
      await diaries.insertADiary(
        makeDiary('r1', 'hello resource', title: 'Resource diary'),
      );

      final categoryData = resourceJson(
        await call('resources/read', {'uri': 'moodiary://categories'}),
      );
      expect(categoryData['total'], 1);
      expect(
        (categoryData['categories'] as List)
            .cast<Map<String, dynamic>>()
            .single['id'],
        categoryId,
      );

      final recent = resourceJson(
        await call('resources/read', {'uri': 'moodiary://diaries/recent'}),
      );
      expect(recent['count'], 1);
      expect(diaryIds(recent), ['r1']);

      final stats = resourceJson(
        await call('resources/read', {'uri': 'moodiary://stats/overview'}),
      );
      expect(stats['totalDiaries'], 1);
      expect(stats['visibleDiaries'], 1);

      final diaryResource = await call('resources/read', {
        'uri': 'moodiary://diary/r1',
      });
      final contents =
          (resultOf(diaryResource)['contents'] as List).single as Map;
      expect(contents['mimeType'], 'text/markdown');
      expect(contents['text'] as String, contains('Resource diary'));
      expect(contents['text'] as String, contains('"id": "r1"'));

      final missing = await call('resources/read', {
        'uri': 'moodiary://diary/ghost',
      });
      expect(errorCode(missing), JsonRpcCode.resourceNotFound);
    });
  });

  group('prompts and completions', () {
    test('prompts render messages and complete known values', () async {
      await newCategory('Travel');
      await diaries.insertADiary(
        makeDiary('p1', 'prompt body', time: DateTime(2020, 1, 15, 12)),
      );

      final daily = resultOf(
        await call('prompts/get', {
          'name': 'daily_review',
          'arguments': {'date': '2026-01-15'},
        }),
      );
      expect(daily['description'], 'Review of 2026-01-15');
      final dailyMessages = daily['messages'] as List;
      expect(dailyMessages, hasLength(1));
      expect((dailyMessages.single as Map)['role'], 'user');
      expect(
        ((dailyMessages.single as Map)['content'] as Map)['text'] as String,
        contains('2026-01-15'),
      );

      final period = resultOf(
        await call('prompts/get', {
          'name': 'summarize_period',
          'arguments': {'start': '2026-01-01', 'end': '2026-01-31'},
        }),
      );
      final periodMessages = period['messages'] as List;
      expect(periodMessages, hasLength(1));
      expect((periodMessages.single as Map)['role'], 'user');
      final periodText =
          ((periodMessages.single as Map)['content'] as Map)['text'] as String;
      expect(periodText, contains('2026-01-01'));
      expect(periodText, contains('2026-01-31'));

      final dates = completionValues(
        await call('completion/complete', {
          'ref': {'type': 'ref/prompt', 'name': 'daily_review'},
          'argument': {'name': 'date', 'value': '2020-01-1'},
        }),
      );
      expect(dates, contains('2020-01-15'));
      expect(dates.every((value) => value.startsWith('2020-01')), isTrue);

      final names = completionValues(
        await call('completion/complete', {
          'ref': {'type': 'ref/prompt', 'name': 'daily_review'},
          'argument': {'name': 'category', 'value': 'Tra'},
        }),
      );
      expect(names, ['Travel']);
    });
  });

  group('invalid arguments', () {
    test('bad calls fail with protocol or tool level errors', () async {
      final missingContent = await toolCall('create_diary', {
        'title': 'No body',
      });
      expect(errorCode(missingContent), JsonRpcCode.invalidParams);
      expect(missingContent.containsKey('result'), isFalse);

      final unknownGet = await toolCall('get_diary', {'id': 'ghost'});
      expect(resultOf(unknownGet)['isError'], isTrue);
      expect(textOf(unknownGet), contains('no diary with id="ghost"'));

      final unknownUpdate = await toolCall('update_diary', {
        'id': 'ghost',
        'title': 'x',
      });
      expect(resultOf(unknownUpdate)['isError'], isTrue);

      await diaries.insertADiary(makeDiary('known', 'body'));
      final noFields = await toolCall('update_diary', {'id': 'known'});
      expect(errorCode(noFields), JsonRpcCode.invalidParams);

      final unknownFormat = await toolCall('create_diary', {
        'content': 'body',
        'contentFormat': 'html',
      });
      expect(errorCode(unknownFormat), JsonRpcCode.invalidParams);
    });
  });
}
