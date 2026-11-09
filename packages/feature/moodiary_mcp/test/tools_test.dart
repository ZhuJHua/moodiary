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

/// A Tiptap document with a heading and one bold paragraph, used to show that a
/// `contentFormat` really reaches the stored document.
String richDocument() => jsonEncode({
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

  String errorMessage(Map<String, dynamic> response) =>
      (response['error'] as Map)['message'] as String;

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

  Map<String, dynamic> singleHit(Map<String, dynamic> data) =>
      (data['hits'] as List).cast<Map<String, dynamic>>().single;

  Map<String, dynamic> storedDoc(String content) =>
      jsonDecode(content) as Map<String, dynamic>;

  List<Map<String, dynamic>> docBlocks(Map<String, dynamic> doc) =>
      (doc['content'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> toolNamed(Map<String, dynamic> listed, String name) =>
      (listed['tools'] as List).cast<Map<String, dynamic>>().firstWhere(
        (tool) => tool['name'] == name,
      );

  Map<String, dynamic> propertiesOf(Map<String, dynamic> tool) =>
      (tool['inputSchema'] as Map<String, dynamic>)['properties']
          as Map<String, dynamic>;

  Future<String> newCategory(
    String name, {
    String? parentId,
    Object? color,
  }) async {
    final created = structuredOf(
      await toolCall('create_category', {
        'name': name,
        'parentId': ?parentId,
        'color': ?color,
      }),
    );
    expect(created['created'], isTrue);
    return (created['category'] as Map<String, dynamic>)['id'] as String;
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
          'render_diary_image',
          'list_diary_media',
          'read_diary_media',
          'add_diary_image',
          'add_diary_attachment',
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

    test('every tool composes the shared argument schemas', () async {
      final listed = resultOf(await call('tools/list'));

      expect(propertiesOf(toolNamed(listed, 'list_diaries')).keys, [
        'categoryId',
        'tag',
        'startDate',
        'endDate',
        'sort',
        'limit',
        'offset',
        'excerpt',
      ]);
      final listSort = propertiesOf(toolNamed(listed, 'list_diaries'))['sort'];
      expect((listSort as Map)['enum'], ['newest', 'oldest', 'modified']);
      expect(listSort['default'], 'newest');
      final excerpt = propertiesOf(
        toolNamed(listed, 'list_diaries'),
      )['excerpt'];
      expect((excerpt as Map)['enum'], ['plain', 'markdown', 'none']);

      expect(propertiesOf(toolNamed(listed, 'get_diary')).keys, [
        'id',
        'contentFormat',
        'linkStyle',
        'includeLinks',
      ]);
      final readFormat = propertiesOf(
        toolNamed(listed, 'get_diary'),
      )['contentFormat'];
      expect((readFormat as Map)['enum'], ['markdown', 'text', 'document']);
      expect(readFormat['default'], 'markdown');
      final linkStyle = propertiesOf(
        toolNamed(listed, 'get_diary'),
      )['linkStyle'];
      expect((linkStyle as Map)['enum'], ['uri', 'label']);
      expect(linkStyle['default'], 'uri');

      expect(propertiesOf(toolNamed(listed, 'create_diary')).keys, [
        'title',
        'content',
        'contentFormat',
        'time',
        'categoryId',
        'mood',
        'tags',
        'visible',
      ]);
      expect(propertiesOf(toolNamed(listed, 'update_diary')).keys, [
        'id',
        'title',
        'content',
        'contentFormat',
        'time',
        'categoryId',
        'mood',
        'tags',
        'visible',
      ]);
      final writeFormat = propertiesOf(
        toolNamed(listed, 'create_diary'),
      )['contentFormat'];
      expect((writeFormat as Map)['enum'], ['markdown', 'text', 'document']);

      expect(propertiesOf(toolNamed(listed, 'delete_diary')).keys, [
        'id',
        'mode',
      ]);
      final mode = propertiesOf(toolNamed(listed, 'delete_diary'))['mode'];
      expect((mode as Map)['enum'], ['permanent', 'recycle']);
      expect(mode['default'], 'permanent');

      expect(propertiesOf(toolNamed(listed, 'search_diaries')).keys, [
        'query',
        'categoryId',
        'startDate',
        'endDate',
        'sort',
        'limit',
        'offset',
        'excerpt',
      ]);
      final searchSort = propertiesOf(
        toolNamed(listed, 'search_diaries'),
      )['sort'];
      expect((searchSort as Map)['enum'], ['relevance', 'newest', 'oldest']);
      expect(searchSort['default'], 'relevance');

      expect(propertiesOf(toolNamed(listed, 'update_category')).keys, [
        'id',
        'name',
        'color',
        'parentId',
      ]);
    });

    test('the tool descriptions explain the clearing rule', () async {
      final listed = resultOf(await call('tools/list'));
      final update = toolNamed(listed, 'update_diary')['description'] as String;
      expect(update, contains('Send null'));
      expect(update, contains('unchanged'));
      final colour = propertiesOf(
        toolNamed(listed, 'create_category'),
      )['color'];
      expect((colour as Map)['description'] as String, contains('#AARRGGBB'));
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
      expect(created.keys, ['created', 'diary']);
      final summary = created['diary'] as Map<String, dynamic>;
      final id = summary['id'] as String;
      expect(summary['title'], 'Morning note');
      expect(summary['time'], '2026-01-15T08:30:00.000Z');
      expect(summary['categoryId'], categoryId);
      expect(summary['categoryName'], 'Journal');
      expect(summary['mood'], 'good');
      expect(summary['tags'], ['food', 'morning']);
      expect(summary['show'], isTrue);

      final stored = await diaries.getDiaryByBusinessId(id);
      expect(stored, isNotNull);
      expect(stored!.contentText, 'apple pie and coffee');

      final read = structuredOf(
        await toolCall('get_diary', {
          'id': id,
          'contentFormat': 'markdown',
          'includeLinks': false,
        }),
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
      expect(read['uri'], 'moodiary://diary/$id');
      expect((read['media'] as Map)['images'], isEmpty);
      // includeLinks=false drops the graph entirely.
      expect(read, isNot(contains('links')));
    });

    test('create_diary stores a hidden diary when visible is false', () async {
      final created = structuredOf(
        await toolCall('create_diary', {
          'content': 'hidden body',
          'visible': false,
        }),
      );
      expect((created['diary'] as Map)['show'], isFalse);
      final id = (created['diary'] as Map)['id'] as String;
      expect((await diaries.getDiaryByBusinessId(id))!.show, isFalse);
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
        expect(updated.keys, ['updated', 'diary']);
        final summary = updated['diary'] as Map<String, dynamic>;
        expect(summary['title'], 'After');
        expect(summary['tags'], ['keep']);
        expect(summary['time'], '2000-01-01T00:00:00.000Z');

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
          await toolCall('get_diary', {'id': 'update-me'}),
        );
        expect(read['content'], 'new body');
      },
    );

    test(
      'update_diary clears nullable fields on null and keeps them on omission',
      () async {
        final categoryId = await newCategory('Keep me');
        await diaries.insertADiary(
          makeDiary(
            'nullable',
            'body',
            categoryId: categoryId,
            tags: ['one', 'two'],
          ),
        );
        await toolCall('update_diary', {'id': 'nullable', 'mood': 'good'});

        final kept = structuredOf(
          await toolCall('update_diary', {'id': 'nullable', 'title': 'Kept'}),
        );
        final keptSummary = kept['diary'] as Map<String, dynamic>;
        expect(keptSummary['categoryId'], categoryId);
        expect(keptSummary['mood'], 'good');
        expect(keptSummary['tags'], ['one', 'two']);

        final cleared = structuredOf(
          await toolCall('update_diary', {
            'id': 'nullable',
            'categoryId': null,
            'mood': null,
            'tags': null,
          }),
        );
        final clearedSummary = cleared['diary'] as Map<String, dynamic>;
        expect(clearedSummary['categoryId'], isNull);
        expect(clearedSummary['mood'], isNull);
        expect(clearedSummary['tags'], isEmpty);

        final stored = (await diaries.getDiaryByBusinessId('nullable'))!;
        expect(stored.categoryId, isNull);
        expect(stored.mood, isNull);
        expect(stored.tags, isEmpty);

        // A title is not nullable, so an empty string is how it is cleared.
        final untitled = structuredOf(
          await toolCall('update_diary', {'id': 'nullable', 'title': ''}),
        );
        expect((untitled['diary'] as Map)['title'], '');
        expect((await diaries.getDiaryByBusinessId('nullable'))!.title, '');
      },
    );

    test(
      'update_diary ignores an explicit null for a non-nullable field',
      () async {
        await diaries.insertADiary(makeDiary('solid', 'body', title: 'Old'));

        final updated = structuredOf(
          await toolCall('update_diary', {
            'id': 'solid',
            'title': 'New',
            'visible': null,
            'time': null,
          }),
        );
        final summary = updated['diary'] as Map<String, dynamic>;
        expect(summary['title'], 'New');
        expect(summary['show'], isTrue);
        expect(summary['time'], '2026-01-01T00:00:00.000Z');
      },
    );

    test('delete_diary reports the mode and the stored title', () async {
      await diaries.insertDiaries([
        makeDiary('recycle-me', 'recycle body', title: 'Recycle'),
        makeDiary('delete-me', 'delete body', title: 'Delete'),
      ]);

      final recycled = structuredOf(
        await toolCall('delete_diary', {'id': 'recycle-me', 'mode': 'recycle'}),
      );
      expect(recycled, {
        'deleted': true,
        'id': 'recycle-me',
        'title': 'Recycle',
        'mode': 'recycle',
      });
      expect((await diaries.getDiaryByBusinessId('recycle-me'))!.show, isFalse);

      final restored = structuredOf(
        await toolCall('update_diary', {'id': 'recycle-me', 'visible': true}),
      );
      expect((restored['diary'] as Map)['show'], isTrue);
      expect((await diaries.getDiaryByBusinessId('recycle-me'))!.show, isTrue);

      final deleted = structuredOf(
        await toolCall('delete_diary', {'id': 'delete-me'}),
      );
      expect(deleted['mode'], 'permanent');
      expect(deleted['deleted'], isTrue);
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
      expect(found['query'], 'apple');
      final hit = singleHit(found);
      expect(hit['id'], 'apple');
      expect(hit['excerpt'] as String, contains('**apple**'));

      final missing = structuredOf(
        await toolCall('search_diaries', {'query': 'zzzz'}),
      );
      expect(missing['total'], 0);
      expect(missing['hits'], isEmpty);
    });

    test('search_diaries sorts by time on request', () async {
      await diaries.insertDiaries([
        makeDiary('older', 'apple older', time: DateTime.utc(2020, 1, 1)),
        makeDiary('newer', 'apple newer', time: DateTime.utc(2026, 1, 1)),
      ]);

      List<String> ids(Map<String, dynamic> data) => [
        for (final hit in (data['hits'] as List).cast<Map<String, dynamic>>())
          hit['id'] as String,
      ];

      final newest = structuredOf(
        await toolCall('search_diaries', {'query': 'apple', 'sort': 'newest'}),
      );
      expect(ids(newest), ['newer', 'older']);

      final oldest = structuredOf(
        await toolCall('search_diaries', {'query': 'apple', 'sort': 'oldest'}),
      );
      expect(ids(oldest), ['older', 'newer']);

      final relevance = structuredOf(
        await toolCall('search_diaries', {'query': 'apple'}),
      );
      expect(ids(relevance), hasLength(2));
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
          await toolCall('list_diaries', {'limit': 2, 'offset': 1}),
        );
        expect(diaryIds(page), ['d4', 'd3']);
        expect(page['count'], 2);
        expect(page['offset'], 1);
        expect(page['limit'], 2);
        expect(page['hasMore'], isTrue);

        final ascending = structuredOf(
          await toolCall('list_diaries', {'limit': 3, 'sort': 'oldest'}),
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
            'startDate': '2026-01-02',
            'endDate': '2026-01-04',
            'sort': 'oldest',
          }),
        );
        expect(diaryIds(byWindow), ['d2', 'd3', 'd4']);
      },
    );

    test('list_diaries filters by an exact tag and pages in memory', () async {
      for (var day = 1; day <= 5; day++) {
        await diaries.insertADiary(
          makeDiary(
            't$day',
            'body $day',
            tags: day.isEven ? ['work'] : ['home'],
            time: DateTime(2026, 1, day, 12),
          ),
        );
      }

      final first = structuredOf(
        await toolCall('list_diaries', {'tag': 'work', 'limit': 1}),
      );
      expect(diaryIds(first), ['t4']);
      expect(first['hasMore'], isTrue);

      final second = structuredOf(
        await toolCall('list_diaries', {
          'tag': 'work',
          'limit': 1,
          'offset': 1,
        }),
      );
      expect(diaryIds(second), ['t2']);
      expect(second['hasMore'], isFalse);

      final unknownTag = structuredOf(
        await toolCall('list_diaries', {'tag': 'missing'}),
      );
      expect(unknownTag['diaries'], isEmpty);
      expect(unknownTag['hasMore'], isFalse);

      final categoryId = await newCategory('Tagged');
      await diaries.insertADiary(
        makeDiary(
          't6',
          'in category',
          tags: ['work'],
          categoryId: categoryId,
          time: DateTime(2026, 1, 6, 12),
        ),
      );
      final scoped = structuredOf(
        await toolCall('list_diaries', {
          'tag': 'work',
          'categoryId': categoryId,
        }),
      );
      expect(diaryIds(scoped), ['t6']);
    });

    test(
      'bug 9: list_diaries and search_diaries reject an unknown category',
      () async {
        await diaries.insertADiary(makeDiary('known', 'body'));

        final listed = await toolCall('list_diaries', {'categoryId': 'ghost'});
        expect(errorCode(listed), JsonRpcCode.invalidParams);
        expect(errorMessage(listed), contains('not a known category'));
        expect(errorMessage(listed), contains('list_categories'));

        final searched = await toolCall('search_diaries', {
          'query': 'body',
          'categoryId': 'ghost',
        });
        expect(errorCode(searched), JsonRpcCode.invalidParams);
        expect(errorMessage(searched), contains('list_categories'));

        // The same id on a write is already an invalid params error.
        final created = await toolCall('create_diary', {
          'content': 'body',
          'categoryId': 'ghost',
        });
        expect(errorCode(created), JsonRpcCode.invalidParams);
      },
    );
  });

  group('body representations', () {
    test('get_diary linkStyle=label drops the link target', () async {
      await diaries.insertDiaries([
        makeDiary('target', 'target body'),
        makeDiary('source', 'see ', linkTo: ['target']),
      ]);

      final withLinks = structuredOf(
        await toolCall('get_diary', {'id': 'source'}),
      );
      expect(withLinks['contentFormat'], 'markdown');
      expect(withLinks['content'], contains('[L](moodiary://diary/target)'));
      expect((withLinks['links'] as Map)['forward'], hasLength(1));

      final labelOnly = structuredOf(
        await toolCall('get_diary', {'id': 'source', 'linkStyle': 'label'}),
      );
      expect(labelOnly['content'], 'see L');
      expect(labelOnly['content'], isNot(contains('moodiary://diary/')));

      final plain = structuredOf(
        await toolCall('get_diary', {'id': 'source', 'contentFormat': 'text'}),
      );
      expect(plain['contentFormat'], 'text');
      expect(plain['content'], 'see L (moodiary://diary/target)');

      final plainLabel = structuredOf(
        await toolCall('get_diary', {
          'id': 'source',
          'contentFormat': 'text',
          'linkStyle': 'label',
        }),
      );
      expect(plainLabel['content'], 'see L');
    });

    test('get_diary contentFormat=text returns the plain body', () async {
      await diaries.insertADiary(
        makeDiary('rich', 'Heading\nbold words', content: richDocument()),
      );

      final markdown = structuredOf(
        await toolCall('get_diary', {'id': 'rich'}),
      );
      expect(markdown['contentFormat'], 'markdown');
      expect(markdown['content'], contains('# Heading'));
      expect(markdown['content'], contains('**bold words**'));

      final plain = structuredOf(
        await toolCall('get_diary', {'id': 'rich', 'contentFormat': 'text'}),
      );
      expect(plain['contentFormat'], 'text');
      expect(plain['content'], 'Heading\nbold words');
      expect(plain['content'], isNot(contains('**')));
      expect(plain['content'], isNot(contains('#')));
    });

    test(
      'contentFormat=document reads and writes the raw Tiptap document',
      () async {
        await diaries.insertADiary(
          makeDiary('rich', 'Heading\nbold words', content: richDocument()),
        );

        final raw = structuredOf(
          await toolCall('get_diary', {
            'id': 'rich',
            'contentFormat': 'document',
          }),
        );
        expect(raw['contentFormat'], 'document');
        expect(raw['content'], isA<Map>());
        expect((raw['content'] as Map)['type'], 'doc');
        expect(raw['contentTruncated'], isFalse);

        final created = structuredOf(
          await toolCall('create_diary', {
            'title': 'Document',
            'content': richDocument(),
            'contentFormat': 'document',
          }),
        );
        final id = (created['diary'] as Map)['id'] as String;
        final stored = (await diaries.getDiaryByBusinessId(id))!;
        expect(stored.type, 'tiptap');
        expect(docBlocks(storedDoc(stored.content)).first['type'], 'heading');

        await toolCall('update_diary', {
          'id': id,
          'content': jsonEncode({
            'type': 'doc',
            'attrs': {'v': 2},
            'content': [
              {
                'type': 'paragraph',
                'content': [
                  {'type': 'text', 'text': 'rewritten'},
                ],
              },
            ],
          }),
          'contentFormat': 'document',
        });
        expect(
          (await diaries.getDiaryByBusinessId(id))!.contentText,
          'rewritten',
        );

        final invalid = await toolCall('create_diary', {
          'content': '{"type":"paragraph"}',
          'contentFormat': 'document',
        });
        expect(errorCode(invalid), JsonRpcCode.invalidParams);
        expect(errorMessage(invalid), contains('Tiptap document'));
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
        (markdown['diary'] as Map)['id'] as String,
      ))!;
      expect(markdownStored.type, 'tiptap');
      final markdownTypes = docBlocks(storedDoc(markdownStored.content))
          .map((block) => block['type']);
      expect(markdownTypes, contains('heading'));
      expect(markdownTypes, contains('bulletList'));

      final markdownRead = structuredOf(
        await toolCall('get_diary', {
          'id': (markdown['diary'] as Map)['id'] as String,
        }),
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
        (text['diary'] as Map)['id'] as String,
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

    test(
      'excerpt=markdown keeps formatting and excerpt=none drops it',
      () async {
        await diaries.insertADiary(
          makeDiary('md', 'Plan\nbody text', content: richDocument()),
        );

        final plain = structuredOf(await toolCall('list_diaries'));
        expect(singleSummary(plain)['excerpt'], 'Heading bold words');

        final marked = structuredOf(
          await toolCall('list_diaries', {'excerpt': 'markdown'}),
        );
        final excerpt = singleSummary(marked)['excerpt'] as String;
        expect(excerpt, contains('# Heading'));
        expect(excerpt, contains('**bold words**'));

        final none = structuredOf(
          await toolCall('list_diaries', {'excerpt': 'none'}),
        );
        expect(singleSummary(none), isNot(contains('excerpt')));
      },
    );

    test('search_diaries excerpt=markdown projects the preview', () async {
      await diaries.insertADiary(
        makeDiary('apple-doc', 'apple\nnote', content: richDocument()),
      );

      final plain = structuredOf(
        await toolCall('search_diaries', {'query': 'Heading'}),
      );
      expect(singleHit(plain)['preview'], 'Heading bold words');
      expect(singleHit(plain)['excerpt'], contains('**Heading**'));

      final marked = structuredOf(
        await toolCall('search_diaries', {
          'query': 'Heading',
          'excerpt': 'markdown',
        }),
      );
      expect(singleHit(marked)['preview'], contains('# Heading'));

      // The highlight snippet is the point of the search, so excerpt=none only
      // drops the preview.
      final none = structuredOf(
        await toolCall('search_diaries', {
          'query': 'Heading',
          'excerpt': 'none',
        }),
      );
      expect(singleHit(none), isNot(contains('preview')));
      expect(singleHit(none)['excerpt'], contains('**Heading**'));
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
        expect(parentNode['diaries'], 0);
        expect(parentNode['diariesTotal'], 0);
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
        expect((renamed['category'] as Map)['name'], 'Projects 2026');

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
        expect(removed['reparentedChildren'], isEmpty);
        expect(await categories.getCategoryById(empty), isNull);

        await diaries.insertADiary(
          makeDiary('busy-diary', 'stays', categoryId: child),
        );
        final refused = structuredOf(
          await toolCall('delete_category', {'id': child}),
        );
        expect(refused['deleted'], isFalse);
        expect(refused['id'], child);
        expect(refused['reparentedChildren'], isEmpty);
        expect(refused['reason'] as String, isNotEmpty);
        expect(await categories.getCategoryById(child), isNotNull);
      },
    );

    test('delete_category re-homes the children it reports', () async {
      final parent = await newCategory('Parent');
      final first = await newCategory('First', parentId: parent);
      final second = await newCategory('Second', parentId: parent);

      final removed = structuredOf(
        await toolCall('delete_category', {'id': parent}),
      );
      expect(removed['deleted'], isTrue);
      expect(
        removed['reparentedChildren'],
        containsAll(<String>[first, second]),
      );
      expect(removed['reparentedChildren'], hasLength(2));
      expect((await categories.getCategoryById(first))!.parentId, isNull);
      expect((await categories.getCategoryById(second))!.parentId, isNull);
    });

    test('bug 6: colour accepts an ARGB integer and both hex forms', () async {
      final fromInt = structuredOf(
        await toolCall('create_category', {'name': 'Int', 'color': 0xFF112233}),
      );
      final intCategory = fromInt['category'] as Map<String, dynamic>;
      expect(intCategory['color'], 0xFF112233);
      expect(intCategory['colorHex'], '#FF112233');

      final fromRgb = structuredOf(
        await toolCall('create_category', {'name': 'RGB', 'color': '#3366CC'}),
      );
      final rgbCategory = fromRgb['category'] as Map<String, dynamic>;
      expect(rgbCategory['color'], 0xFF3366CC);
      expect(rgbCategory['colorHex'], '#FF3366CC');

      final fromArgb = structuredOf(
        await toolCall('create_category', {
          'name': 'ARGB',
          'color': '#80112233',
        }),
      );
      final argbCategory = fromArgb['category'] as Map<String, dynamic>;
      expect(argbCategory['color'], 0x80112233);
      expect(argbCategory['colorHex'], '#80112233');
    });

    test('bug 6: an empty string or null clears the colour', () async {
      final id = await newCategory('Clearable', color: 0xFF445566);

      final clearedByEmpty = structuredOf(
        await toolCall('update_category', {'id': id, 'color': ''}),
      );
      expect((clearedByEmpty['category'] as Map)['color'], isNull);
      expect((clearedByEmpty['category'] as Map)['colorHex'], isNull);
      expect((await categories.getCategoryById(id))!.color, isNull);

      await toolCall('update_category', {'id': id, 'color': '#00FF00'});
      expect((await categories.getCategoryById(id))!.color, 0xFF00FF00);

      final clearedByNull = structuredOf(
        await toolCall('update_category', {'id': id, 'color': null}),
      );
      expect((clearedByNull['category'] as Map)['color'], isNull);

      // Omitting the field leaves the stored colour alone.
      await toolCall('update_category', {'id': id, 'color': '#0000FF'});
      final renamed = structuredOf(
        await toolCall('update_category', {'id': id, 'name': 'Renamed'}),
      );
      expect((renamed['category'] as Map)['color'], 0xFF0000FF);
    });

    test('bug 6: a wrong colour value explains the accepted forms', () async {
      final id = await newCategory('Wrong colour');
      final response = await toolCall('update_category', {
        'id': id,
        'color': 'red',
      });
      expect(errorCode(response), JsonRpcCode.invalidParams);
      final message = errorMessage(response);
      expect(message, contains('#RRGGBB'));
      expect(message, contains('#AARRGGBB'));
      expect(message, contains('empty string'));
    });

    test(
      'update_category clears the parent with null and keeps it on omission',
      () async {
        final parent = await newCategory('Root');
        final child = await newCategory('Child', parentId: parent);

        final kept = structuredOf(
          await toolCall('update_category', {'id': child, 'name': 'Child 2'}),
        );
        expect((kept['category'] as Map)['parentId'], parent);

        final cleared = structuredOf(
          await toolCall('update_category', {'id': child, 'parentId': null}),
        );
        expect((cleared['category'] as Map)['parentId'], isNull);
        expect((await categories.getCategoryById(child))!.parentId, isNull);
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
      expect((stats['monthsWindow'] as Map).keys, ['from', 'to']);
      expect(stats['olderDiaries'], isA<int>());
      expect(stats['futureDiaries'], isA<int>());
      final months = (stats['months'] as List).cast<Map<String, dynamic>>();
      final bucketSum = months.fold<int>(
        0,
        (sum, row) => sum + (row['diaries'] as int),
      );
      expect(
        bucketSum +
            (stats['olderDiaries'] as int) +
            (stats['futureDiaries'] as int),
        stats['visibleDiaries'],
      );
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
      expect(tags['note'] as String, isNotEmpty);
    });
  });

  group('links', () {
    test(
      'get_diary_links reports forward links, backlinks and dangling ids',
      () async {
        await diaries.insertDiaries([
          makeDiary('target', 'target body'),
          makeDiary('source-a', 'source a', linkTo: ['target']),
          makeDiary('source-b', 'source b', linkTo: ['target', 'ghost']),
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
        expect(forward['dangling'], isEmpty);

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

        final dangling = structuredOf(
          await toolCall('get_diary_links', {'id': 'source-b'}),
        );
        expect(dangling['dangling'], ['ghost']);
      },
    );
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
      expect(stats['monthsWindow'], isNotNull);

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

      // An explicit null on every nullable field is still a real change.
      final clearedOnly = await toolCall('update_diary', {
        'id': 'known',
        'tags': null,
      });
      expect(resultOf(clearedOnly)['isError'], isFalse);

      final unknownFormat = await toolCall('create_diary', {
        'content': 'body',
        'contentFormat': 'html',
      });
      expect(errorCode(unknownFormat), JsonRpcCode.invalidParams);

      final unknownExcerpt = await toolCall('list_diaries', {
        'excerpt': 'short',
      });
      expect(errorCode(unknownExcerpt), JsonRpcCode.invalidParams);

      final reversedRange = await toolCall('list_diaries', {
        'startDate': '2026-02-01',
        'endDate': '2026-01-01',
      });
      expect(errorCode(reversedRange), JsonRpcCode.invalidParams);
      expect(errorMessage(reversedRange), contains('startDate'));
    });
  });
}
