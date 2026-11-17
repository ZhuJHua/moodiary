import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import '../support.dart';

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
  late TestToolClient client;
  setUp(() {
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    db = openTestDatabase();
    diaries = DiaryRepository(db);
    categories = CategoryRepository(db);
    client = TestToolClient(
      ToolContext(
        diaries: diaries,
        categories: categories,
        insights: MoodInsightsRepository(db),
        surface: ToolSurface.mcp,
      ),
    );
  });
  tearDown(() async {
    await getIt.reset();
    await db.close();
  });

  Future<Map<String, dynamic>> run(
    String name, [
    Map<String, dynamic> args = const {},
  ]) async => (await client.toolCall(name, args)).data;
  Map<String, dynamic> row(Map<String, dynamic> data) =>
      ((data['results'] as List).single as Map).cast<String, dynamic>();
  Map<String, dynamic> diaryOf(Map<String, dynamic> data) =>
      ((data['diaries'] as List).single as Map).cast<String, dynamic>();
  List<String> hitIds(Map<String, dynamic> data) => [
    for (final hit in data['hits'] as List) hit['id'] as String,
  ];

  test(
    'both surfaces default to 10 rows, clamp to 50 and retain SQL paging',
    () async {
      await diaries.insertDiaries([
        for (var index = 0; index < 60; index++)
          makeDiary('entry-$index', 'orchard'),
      ]);
      final definition = moodiaryTools.firstWhere(
        (tool) => tool.name == 'search_diaries',
      );
      expect(
        definition.description(ToolSurface.mcp),
        definition.description(ToolSurface.assistant),
      );
      expect(
        definition.input(ToolSurface.mcp).value,
        definition.input(ToolSurface.assistant).value,
      );
      for (final surface in ToolSurface.values) {
        final context = ToolContext(
          diaries: diaries,
          categories: categories,
          insights: MoodInsightsRepository(db),
          surface: surface,
        );
        final properties = definition.input(surface).value['properties'] as Map;
        final limit =
            ((properties['limit'] as Map)['anyOf'] as List).first as Map;
        expect(limit['default'], 10);
        expect(limit['description'], contains('1..50'));
        for (final query in [null, 'orchard']) {
          for (final requested in [null, 0, -1, 1000]) {
            final result = (await definition.call({
              'query': ?query,
              'limit': ?requested,
            }, context)).data;
            final expected = requested == null
                ? 10
                : requested < 1
                ? 1
                : 50;
            expect(result['limit'], expected);
            expect(result['hits'], hasLength(expected));
            expect(result['total'], 60);
          }
          final beyondWindow = (await definition.call({
            'query': ?query,
            'offset': 50,
          }, context)).data;
          expect(beyondWindow['hits'], hasLength(10));
          expect(beyondWindow['totalIsLowerBound'], isFalse);
        }
      }
    },
  );

  test('a recycled diary is hidden from read and write tools', () async {
    await diaries.insertADiary(
      makeDiary('bin', 'hidden body', title: 'Hidden', show: false),
    );
    final before = (await diaries.getDiaryByBusinessId('bin'))!;
    final read = await run('get_diary', {
      'ids': ['bin'],
    });
    expect(read['diaries'], isEmpty);
    expect(read['missing'], ['bin']);
    final mediaClient = TestToolClient(
      ToolContext(
        diaries: diaries,
        categories: categories,
        insights: MoodInsightsRepository(db),
        surface: ToolSurface.mcp,
        mediaStore: DiaryMediaStore(
          pathOf: (kind, name) =>
              fail('Recycled diary accessed media: $kind/$name'),
        ),
      ),
    );
    for (final (name, arguments) in <(String, Map<String, dynamic>)>[
      ('get_diary_links', {'id': 'bin'}),
      ('list_diary_media', {'id': 'bin'}),
      ('read_diary_media', {'id': 'bin', 'name': 'image-hidden.png'}),
      ('add_diary_image', {'id': 'bin', 'data': 'YQ=='}),
      (
        'add_diary_attachment',
        {'id': 'bin', 'data': 'YQ==', 'fileName': 'hidden.txt'},
      ),
    ]) {
      final response = mediaClient.toolCall(name, arguments);

      await expectLater(
        response,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('no diary with id="bin"'),
          ),
        ),
      );
    }
    for (final query in [null, 'hidden']) {
      final search = await run('search_diaries', {'query': ?query});
      expect(search['hits'], isEmpty);
      expect(search['total'], 0);
    }
    final updated = row(
      await run('update_diary', {
        'items': [
          {'id': 'bin', 'title': 'changed', 'content': 'changed body'},
        ],
      }),
    );
    expect(updated['ok'], false);
    expect(updated['error'], contains('no diary with id="bin"'));
    expect(await diaries.getDiaryByBusinessId('bin'), before);
  });

  test('category colour accepts an ARGB integer and both hex forms', () async {
    final inputs = <Object>[0xFF112233, '#3366CC', '#80112233'];
    final colors = [0xFF112233, 0xFF3366CC, 0x80112233];
    final hexColors = ['#FF112233', '#FF3366CC', '#80112233'];
    final created = await run('create_category', {
      'items': [
        for (var index = 0; index < inputs.length; index++)
          {'name': 'Colour $index', 'color': inputs[index]},
      ],
    });
    final results = (created['results'] as List).cast<Map>();
    for (var index = 0; index < results.length; index++) {
      expect(results[index]['ok'], true);
      final category = results[index]['category'] as Map;
      expect(category['color'], colors[index]);
      expect(category['colorHex'], hexColors[index]);
      expect(
        (await categories.getCategoryById(category['id'] as String))!.color,
        colors[index],
      );
    }
  });

  test('a wrong category colour explains the accepted forms', () async {
    final id = await client.newCategory('Wrong colour', color: 0xFF445566);
    final invalid = row(
      await run('update_category', {
        'items': [
          {'id': id, 'color': 'red'},
        ],
      }),
    );
    expect(invalid['ok'], false);
    expect(invalid['error'], contains('color'));
    expect(invalid['error'], contains('ARGB'));
    expect(invalid['error'], contains('#RRGGBB'));
    expect(invalid['error'], contains('#AARRGGBB'));
    expect(invalid['error'], contains('empty string'));
    expect((await categories.getCategoryById(id))!.color, 0xFF445566);
  });

  test(
    'an empty string or null clears category colour; omission keeps it',
    () async {
      final id = await client.newCategory('Clearable', color: 0xFF445566);
      for (final value in ['', null]) {
        final cleared = row(
          await run('update_category', {
            'items': [
              {'id': id, 'color': value},
            ],
          }),
        );
        expect(cleared['ok'], true);
        expect(cleared['category']['color'], isNull);
        expect(cleared['category']['colorHex'], isNull);
        expect((await categories.getCategoryById(id))!.color, isNull);
        await run('update_category', {
          'items': [
            {'id': id, 'color': '#0000FF'},
          ],
        });
      }
      final renamed = row(
        await run('update_category', {
          'items': [
            {'id': id, 'name': 'Renamed'},
          ],
        }),
      );
      expect(renamed['category']['color'], 0xFF0000FF);
      expect((await categories.getCategoryById(id))!.color, 0xFF0000FF);
    },
  );

  test(
    'schema failures throw ToolArgumentException naming the invalid field',
    () async {
      final invalidCalls = <(String, Map<String, Object?>, String)>[
        (
          'create_diary',
          {
            'items': [
              {'title': 'Missing body'},
            ],
          },
          'content',
        ),
        (
          'create_diary',
          {
            'items': [
              {'content': 123},
            ],
          },
          'content',
        ),
        ('get_diary', {'ids': 'not an array'}, 'ids'),
        ('search_diaries', {'excerpt': 'short'}, 'excerpt'),
      ];
      for (final (name, arguments, field) in invalidCalls) {
        final definition = moodiaryTools.firstWhere(
          (tool) => tool.name == name,
        );
        await expectLater(
          definition.call(arguments, client.context),
          throwsA(
            isA<ToolArgumentException>().having(
              (error) => error.message,
              'message',
              allOf(contains(name), contains(field)),
            ),
          ),
        );
      }
      expect(await diaries.countAllDiaries(), 0);
    },
  );

  test(
    'unknown diary and category ids return item errors or a missing list',
    () async {
      final read = await run('get_diary', {
        'ids': ['ghost'],
      });
      expect(read['diaries'], isEmpty);
      expect(read['missing'], ['ghost']);
      for (final name in ['update_diary', 'update_category']) {
        final updated = row(
          await run(name, {
            'items': [
              {
                'id': 'ghost',
                if (name == 'update_diary') 'title': 'x' else 'name': 'x',
              },
            ],
          }),
        );
        expect(updated['id'], 'ghost');
        expect(updated['ok'], false);
        expect(updated['error'], contains('ghost'));
      }
      for (final name in ['delete_diary', 'delete_category']) {
        final deleted = row(
          await run(name, {
            'ids': ['ghost'],
          }),
        );
        expect(deleted['id'], 'ghost');
        expect(deleted['ok'], false);
        expect(deleted['error'], contains('ghost'));
      }
    },
  );

  test('list_categories uses each category own visible diary count', () async {
    final work = await client.newCategory('Work');
    final projects = Category.create(categoryName: 'Projects', parentId: work);
    await categories.insertACategory(projects);
    await diaries.insertDiaries([
      makeDiary('work', 'one', categoryId: work),
      makeDiary('project-1', 'two', categoryId: projects.id),
      makeDiary('project-2', 'three', categoryId: projects.id),
      makeDiary('hidden', 'four', categoryId: work, show: false),
    ]);
    final listed = await run('list_categories');
    expect(listed['total'], 2);
    expect(
      {
        for (final category in listed['categories'] as List)
          category['id']: category['diaries'],
      },
      {work: 1, projects.id: 2},
    );
  });

  test(
    'delete_category refuses a non-empty category without changing its rows',
    () async {
      final id = await client.newCategory('Busy');
      final child = Category.create(categoryName: 'Child', parentId: id);
      await categories.insertACategory(child);
      await diaries.insertADiary(makeDiary('kept', 'body', categoryId: id));
      final before = (await diaries.getDiaryByBusinessId('kept'))!;
      final deleted = row(
        await run('delete_category', {
          'ids': [id],
        }),
      );
      expect(deleted['id'], id);
      expect(deleted['ok'], false);
      expect(deleted['error'], contains('still holds diaries'));
      expect(await categories.getCategoryById(id), isNotNull);
      expect(await categories.getCategoryById(child.id), child);
      expect(await diaries.getDiaryByBusinessId('kept'), before);
      final blank = row(
        await run('create_category', {
          'items': [
            {'name': '   '},
          ],
        }),
      );
      expect(blank['ok'], false);
      expect(blank['error'], contains('must not be empty'));
      await diaries.updateADiary(newDiary: before.copyWith(show: false));
      final recycled = row(
        await run('delete_category', {
          'ids': [id],
        }),
      );
      expect(recycled['ok'], false);
      expect(recycled['error'], contains('recycle bin'));
    },
  );

  test('delete_category leaves child categories untouched after deleting an empty parent', () async {
    final parent = await client.newCategory('Root');
    final child = Category.create(categoryName: 'Child', parentId: parent);
    await categories.insertACategory(child);
    final deleted = row(
      await run('delete_category', {
        'ids': [parent],
      }),
    );
    expect(deleted['ok'], true);
    expect(await categories.getCategoryById(parent), isNull);
    expect(await categories.getCategoryById(child.id), child);
  });

  test(
    'update_category preserves the stored parent when renaming and recolouring',
    () async {
      final parent = await client.newCategory('Root');
      final child = Category.create(categoryName: 'Child', parentId: parent);
      await categories.insertACategory(child);
      final updated = row(
        await run('update_category', {
          'items': [
            {'id': child.id, 'name': 'Child 2', 'color': '#112233'},
          ],
        }),
      );
      expect(updated['ok'], true);
      expect(updated['category']['name'], 'Child 2');
      final stored = (await categories.getCategoryById(child.id))!;
      expect(stored.categoryName, 'Child 2');
      expect(stored.color, 0xFF112233);
      expect(stored.parentId, parent);
    },
  );

  test(
    'search count and paging share category and inclusive timestamp filters',
    () async {
      final category = await client.newCategory('Orchard');
      final start = DateTime.utc(2026, 1, 2);
      final end = DateTime.utc(2026, 1, 3);
      await diaries.insertDiaries([
        makeDiary(
          'before',
          'orchard',
          categoryId: category,
          time: start.subtract(const Duration(microseconds: 1)),
        ),
        makeDiary('start', 'orchard', categoryId: category, time: start),
        makeDiary('end', 'orchard', categoryId: category, time: end),
        makeDiary(
          'after',
          'orchard',
          categoryId: category,
          time: end.add(const Duration(microseconds: 1)),
        ),
        makeDiary('other-category', 'orchard', time: start),
        makeDiary(
          'hidden',
          'orchard',
          categoryId: category,
          time: start,
          show: false,
        ),
      ]);
      for (final query in [null, 'orchard']) {
        for (var offset = 0; offset < 2; offset++) {
          final page = await run('search_diaries', {
            'query': ?query,
            'categoryId': category,
            'startDate': start.toIso8601String(),
            'endDate': end.toIso8601String(),
            'sort': 'oldest',
            'offset': offset,
            'limit': 1,
          });
          expect(page['total'], 2);
          expect(page['totalIsLowerBound'], false);
          expect(page['hasMore'], offset == 0);
          expect(singleHit(page)['id'], offset == 0 ? 'start' : 'end');
          expect(singleHit(page)['categoryName'], 'Orchard');
        }
      }
    },
  );

  test(
    'keyword paging retains exact totals and FTS highlight markers',
    () async {
      await diaries.insertDiaries([
        for (var index = 0; index < 3; index++)
          makeDiary(
            'entry-$index',
            'orchard',
            title: 'orchard $index',
            time: DateTime.utc(2026, 1, index + 1),
          ),
      ]);
      final page = await run('search_diaries', {
        'query': 'orchard',
        'sort': 'oldest',
        'offset': 1,
        'limit': 1,
      });
      expect(page['total'], 3);
      expect(page['totalIsLowerBound'], false);
      expect(page['offset'], 1);
      expect(page['limit'], 1);
      expect(page['hasMore'], true);
      final hit = singleHit(page);
      expect(hit['id'], 'entry-1');
      expect(hit['titleHighlight'], '**orchard** 1');
      expect(hit['excerpt'], '**orchard**');
      expect(hit['preview'], 'orchard');
      final last = await run('search_diaries', {
        'query': 'orchard',
        'sort': 'oldest',
        'offset': 2,
        'limit': 2,
      });
      expect(singleHit(last)['id'], 'entry-2');
      expect(last['total'], 3);
      expect(last['hasMore'], false);
      final beyond = await run('search_diaries', {
        'query': 'orchard',
        'offset': 10,
        'limit': 1,
      });
      expect(beyond['total'], 3);
      expect(beyond['hits'], isEmpty);
      expect(beyond['hasMore'], false);
    },
  );

  test('create_diary always stores a visible diary', () async {
    final created = row(
      await run('create_diary', {
        'items': [
          {'content': 'new body'},
        ],
      }),
    );
    expect(created['ok'], true);
    expect(created['diary']['show'], true);
    expect(
      (await diaries.getDiaryByBusinessId(created['diary']['id'] as String))!
          .show,
      true,
    );
  });

  test('create_diary and get_diary round-trip metadata and body', () async {
    final category = await client.newCategory('Journal');
    final created = row(
      await run('create_diary', {
        'items': [
          {
            'title': 'Morning note',
            'content': 'apple pie and coffee',
            'time': '2026-01-15T08:30:00Z',
            'categoryId': category,
            'mood': 'good',
            'tags': ['food', 'morning'],
          },
        ],
      }),
    );
    expect(created['ok'], true);
    final summary = created['diary'] as Map;
    final id = summary['id'] as String;
    final read = diaryOf(
      await run('get_diary', {
        'ids': [id],
        'includeLinks': false,
      }),
    );
    for (final data in [summary, read]) {
      expect(data['title'], 'Morning note');
      expect(data['time'], '2026-01-15T08:30:00.000Z');
      expect(data['categoryId'], category);
      expect(data['categoryName'], 'Journal');
      expect(data['mood'], 'good');
      expect(data['tags'], ['food', 'morning']);
      expect(data['show'], true);
    }
    expect(
      (await diaries.getDiaryByBusinessId(id))!.contentText,
      'apple pie and coffee',
    );
    expect(read['contentFormat'], 'markdown');
    expect(read['content'], 'apple pie and coffee');
    expect(read['truncated'], false);
    expect(read['truncated'], false);
    expect(read['uri'], 'moodiary://diary/$id');
    expect(read['media']['images'], isEmpty);
    expect(read, isNot(contains('links')));
  });

  test(
    'create_diary contentFormat distinguishes Markdown from literal text',
    () async {
      final created = await run('create_diary', {
        'items': [
          {'content': '# Heading\n\n- one\n- two'},
          {'content': '# Heading', 'contentFormat': 'text'},
        ],
      });
      final results = (created['results'] as List).cast<Map>();
      expect(results.map((item) => item['ok']), [true, true]);
      final markdown = (await diaries.getDiaryByBusinessId(
        results.first['diary']['id'] as String,
      ))!;
      expect(markdown.type, 'tiptap');
      final markdownTypes = docBlocks(storedDoc(markdown.content))
          .map((block) => block['type']);
      expect(markdownTypes, contains('heading'));
      expect(markdownTypes, contains('bulletList'));
      final read = diaryOf(
        await run('get_diary', {
          'ids': [markdown.id],
        }),
      );
      expect(read['content'], contains('# Heading'));
      expect(read['content'], contains('- one'));
      final text = (await diaries.getDiaryByBusinessId(
        results.last['diary']['id'] as String,
      ))!;
      final blocks = docBlocks(storedDoc(text.content));
      expect(blocks, hasLength(1));
      expect(blocks.single['type'], 'paragraph');
      expect(text.contentText, '# Heading');
    },
  );

  test(
    'update_diary contentFormat distinguishes Markdown from literal text',
    () async {
      await diaries.insertADiary(makeDiary('edit', 'start'));
      for (final format in ['markdown', 'text']) {
        final updated = row(
          await run('update_diary', {
            'items': [
              {'id': 'edit', 'content': '## Later', 'contentFormat': format},
            ],
          }),
        );
        expect(updated['ok'], true);
        final stored = (await diaries.getDiaryByBusinessId('edit'))!;
        final blocks = docBlocks(storedDoc(stored.content));
        expect(
          blocks.single['type'],
          format == 'markdown' ? 'heading' : 'paragraph',
        );
        expect(stored.contentText, format == 'markdown' ? 'Later' : '## Later');
      }
    },
  );

  test(
    'create_diary refuses Markdown and document bodies that name media',
    () async {
      final created = await run('create_diary', {
        'items': [
          {'content': '![cat](image-abc.png)'},
          {
            'content': jsonEncode({
              'type': 'doc',
              'attrs': {'v': 2},
              'content': [
                {
                  'type': 'image',
                  'attrs': {'src': 'image-abc.png'},
                },
              ],
            }),
            'contentFormat': 'document',
          },
        ],
      });
      for (final item in created['results'] as List) {
        expect(item['ok'], false);
        expect(item['error'], contains('add_diary_image'));
      }
      expect(await diaries.countAllDiaries(), 0);
    },
  );

  test('update_diary refuses media owned by another diary without changing either diary', () async {
    await diaries.insertDiaries([
      makeDiary(
        'owner',
        'owner body',
        media: [
          {
            'type': 'image',
            'attrs': {'src': 'image-owned.png'},
          },
        ],
      ),
      makeDiary('other', 'unchanged'),
    ]);
    final owner = (await diaries.getDiaryByBusinessId('owner'))!;
    final other = (await diaries.getDiaryByBusinessId('other'))!;
    final updated = await run('update_diary', {
      'items': [
        {'id': 'other', 'content': '![cat](image-owned.png)'},
        {
          'id': 'other',
          'content': jsonEncode({
            'type': 'doc',
            'attrs': {'v': 2},
            'content': [
              {
                'type': 'image',
                'attrs': {'src': 'image-owned.png'},
              },
            ],
          }),
          'contentFormat': 'document',
        },
      ],
    });
    for (final item in updated['results'] as List) {
      expect(item['ok'], false);
      expect(item['error'], contains('add_diary_image'));
    }
    expect(await diaries.getDiaryByBusinessId('owner'), owner);
    expect(await diaries.getDiaryByBusinessId('other'), other);
  });

  test(
    'delete_diary recycles entries and reports already-recycled rows',
    () async {
      await diaries.insertADiary(makeDiary('trash', 'kept body'));
      final removed = row(
        await run('delete_diary', {
          'ids': ['trash'],
        }),
      );
      expect(removed['ok'], true);
      expect(removed['id'], 'trash');
      expect(removed['title'], 'title-trash');
      expect(removed['alreadyRecycled'] ?? false, false);
      final stored = (await diaries.getDiaryByBusinessId('trash'))!;
      expect(stored.show, false);
      expect(stored.contentText, 'kept body');
      final repeated = row(
        await run('delete_diary', {
          'ids': ['trash'],
        }),
      );
      expect(repeated['ok'], true);
      expect(repeated['alreadyRecycled'], true);
      expect(await diaries.getDiaryByBusinessId('trash'), stored);
    },
  );

  test('get_diary contentFormat=text returns the plain body', () async {
    await diaries.insertADiary(
      makeDiary('rich', 'Heading\nbold words', content: richDocument()),
    );
    final markdown = diaryOf(
      await run('get_diary', {
        'ids': ['rich'],
      }),
    );
    expect(markdown['content'], contains('# Heading'));
    expect(markdown['content'], contains('**bold words**'));
    final plain = diaryOf(
      await run('get_diary', {
        'ids': ['rich'],
        'contentFormat': 'text',
      }),
    );
    expect(plain['contentFormat'], 'text');
    expect(plain['content'], 'Heading\nbold words');
  });

  test(
    'get_diary linkStyle=label drops diary link targets in Markdown and text',
    () async {
      await diaries.insertDiaries([
        makeDiary('target', 'target body'),
        makeDiary('source', 'see ', linkTo: ['target']),
      ]);
      for (final format in ['markdown', 'text']) {
        final linked = diaryOf(
          await run('get_diary', {
            'ids': ['source'],
            'contentFormat': format,
          }),
        );
        expect(linked['content'], contains('moodiary://diary/target'));
        expect((linked['links']['forward'] as List).single['id'], 'target');
        final labels = diaryOf(
          await run('get_diary', {
            'ids': ['source'],
            'contentFormat': format,
            'linkStyle': 'label',
          }),
        );
        expect(labels['content'], 'see L');
        expect(labels['content'], isNot(contains('moodiary://diary/')));
      }
    },
  );

  test(
    'search_diaries finds body words when the title does not match',
    () async {
      await diaries.insertDiaries([
        makeDiary('found', 'apple pie and coffee', title: 'Breakfast'),
        makeDiary('other', 'a walk outside', title: 'Evening'),
        makeDiary('hidden', 'apple', show: false),
      ]);
      final found = await run('search_diaries', {'query': 'apple'});
      expect(found['total'], 1);
      expect(singleHit(found)['id'], 'found');
      expect(singleHit(found)['title'], 'Breakfast');
      expect(singleHit(found)['excerpt'], contains('**apple**'));
    },
  );

  test(
    'search_diaries returns an exact zero total and empty page for no hits',
    () async {
      await diaries.insertADiary(makeDiary('known', 'apple pie'));
      final empty = await run('search_diaries', {'query': 'unmatched'});
      expect(empty['total'], 0);
      expect(empty['totalIsLowerBound'], false);
      expect(empty['hits'], isEmpty);
      expect(empty['hasMore'], false);
    },
  );

  test(
    'search_diaries sorts matching diaries by time when requested',
    () async {
      await diaries.insertDiaries([
        makeDiary('middle', 'apple', time: DateTime.utc(2026, 1, 2)),
        makeDiary('newest', 'apple', time: DateTime.utc(2026, 1, 3)),
        makeDiary('oldest', 'apple', time: DateTime.utc(2026, 1, 1)),
      ]);
      final ascending = await run('search_diaries', {
        'query': 'apple',
        'sort': 'oldest',
      });
      expect(hitIds(ascending), ['oldest', 'middle', 'newest']);
      final descending = await run('search_diaries', {
        'query': 'apple',
        'sort': 'newest',
      });
      expect(hitIds(descending), ['newest', 'middle', 'oldest']);
    },
  );

  test('search_diaries excerpt=markdown preserves preview formatting and keyword highlights', () async {
    await diaries.insertADiary(
      makeDiary('rich', 'Heading\nbold words', content: richDocument()),
    );
    final plain = singleHit(await run('search_diaries', {'query': 'Heading'}));
    expect(plain['excerpt'], contains('**Heading**'));
    expect(plain['preview'], 'Heading bold words');
    final markdown = singleHit(
      await run('search_diaries', {'query': 'Heading', 'excerpt': 'markdown'}),
    );
    expect(markdown['excerpt'], contains('**Heading**'));
    expect(markdown['preview'], contains('# Heading'));
    expect(markdown['preview'], contains('**bold words**'));
    final none = singleHit(
      await run('search_diaries', {'query': 'Heading', 'excerpt': 'none'}),
    );
    expect(none['excerpt'], contains('**Heading**'));
    expect(none, isNot(contains('preview')));
  });

  test(
    'search_diaries browses exact tags with correct paging and category scope',
    () async {
      for (var day = 1; day <= 5; day++) {
        await diaries.insertADiary(
          makeDiary(
            'tag-$day',
            'body',
            tags: day.isEven ? ['work'] : ['home'],
            time: DateTime(2026, 1, day, 12),
          ),
        );
      }
      await diaries.insertADiary(
        makeDiary('partial-tag', 'body', tags: ['homework']),
      );
      for (final query in [null, 'body']) {
        final first = await run('search_diaries', {
          'query': ?query,
          'tag': 'work',
          'limit': 1,
          'sort': 'newest',
        });
        expect(hitIds(first), ['tag-4']);
        expect(first['total'], 2);
        expect(first['hasMore'], true);
        final second = await run('search_diaries', {
          'query': ?query,
          'tag': 'work',
          'limit': 1,
          'offset': 1,
          'sort': 'newest',
        });
        expect(hitIds(second), ['tag-2']);
        expect(second['total'], 2);
        expect(second['hasMore'], false);
      }
      final unknown = await run('search_diaries', {'tag': 'missing'});
      expect(unknown['total'], 0);
      expect(unknown['hits'], isEmpty);
      expect(unknown['hasMore'], false);
      final category = await client.newCategory('Tagged');
      await diaries.insertADiary(
        makeDiary('scoped', 'body', categoryId: category, tags: ['work']),
      );
      final scoped = await run('search_diaries', {
        'tag': 'work',
        'categoryId': category,
      });
      expect(scoped['total'], 1);
      expect(hitIds(scoped), ['scoped']);
    },
  );

  test('list_tags aggregates usage over visible diaries only', () async {
    await diaries.insertDiaries([
      makeDiary('first', 'a', tags: ['travel', 'food']),
      makeDiary('second', 'b', tags: ['travel']),
      makeDiary('hidden', 'c', tags: ['travel', 'hidden-only'], show: false),
    ]);
    final tags = await run('list_tags');
    expect(
      {for (final tag in tags['tags'] as List) tag['tag']: tag['diaries']},
      {'travel': 2, 'food': 1},
    );
    expect((tags['tags'] as List).first['tag'], 'travel');
    expect(tags['count'], 2);
    expect(tags['totalDistinct'], 2);
    expect(tags['scannedDiaries'], 2);
  });

  test(
    'get_stats reports total, visible, recycled and each category own counts',
    () async {
      final work = await client.newCategory('Work');
      final life = Category.create(categoryName: 'Life', parentId: work);
      await categories.insertACategory(life);
      await diaries.insertDiaries([
        makeDiary(
          'work',
          'one',
          categoryId: work,
          mood: DiaryMood.good,
          time: DateTime.utc(2026, 1, 1),
        ),
        makeDiary('life-1', 'two', categoryId: life.id, mood: DiaryMood.great),
        makeDiary('life-2', 'three', categoryId: life.id, mood: DiaryMood.bad),
        makeDiary('unset', 'four', time: DateTime.utc(2030, 1, 1)),
        makeDiary(
          'hidden',
          'five',
          categoryId: work,
          show: false,
          time: DateTime.utc(2000, 1, 1),
        ),
      ]);
      final stats = await run('get_stats');
      expect(stats['totalDiaries'], 5);
      expect(stats['visibleDiaries'], 4);
      expect(stats['recycleBinDiaries'], 1);
      expect(stats['uncategorizedDiaries'], 1);
      expect(stats['firstDiaryTime'], '2026-01-01T00:00:00.000Z');
      expect(stats['lastDiaryTime'], '2030-01-01T00:00:00.000Z');
      final moods = stats['moods'] as Map;
      expect(moods['diariesWithoutMood'], 1);
      expect(moods['distribution'], {
        'awful': 0,
        'bad': 1,
        'okay': 0,
        'good': 1,
        'great': 1,
      });

      expect(
        {
          for (final category in stats['categories'] as List)
            category['categoryId']: category['diaries'],
        },
        {work: 1, life.id: 2},
      );
    },
  );

  test(
    'search merges browsing, paging, exact tags and date/category filters',
    () async {
      final category = await client.newCategory('Orchard');
      await diaries.insertDiaries([
        makeDiary(
          'before',
          'apple',
          categoryId: category,
          time: DateTime(2026, 1, 1, 23, 59),
        ),
        makeDiary(
          'start',
          'apple',
          categoryId: category,
          tags: ['fruit'],
          time: DateTime(2026, 1, 2),
        ),
        makeDiary(
          'end',
          'apple',
          categoryId: category,
          tags: ['fruit'],
          time: DateTime(2026, 1, 3, 23, 59, 59),
        ),
        makeDiary(
          'after',
          'apple',
          categoryId: category,
          time: DateTime(2026, 1, 4),
        ),
        makeDiary('other', 'apple', time: DateTime(2026, 1, 2)),
        makeDiary('hidden', 'apple', show: false, categoryId: category),
      ]);
      for (final query in [null, 'apple']) {
        final filters = {
          'query': ?query,
          'categoryId': category,
          'startDate': '2026-01-02',
          'endDate': '2026-01-03',
          'tag': 'fruit',
          'sort': 'oldest',
          'limit': 1,
        };
        final page = await run('search_diaries', filters);
        expect(page['total'], 2);
        expect(page['totalIsLowerBound'], false);
        expect(page['hasMore'], true);
        expect(singleHit(page)['id'], 'start');
        expect(singleHit(page)['categoryName'], 'Orchard');
        final last = await run('search_diaries', {...filters, 'offset': 1});
        expect(last['hasMore'], false);
        expect(singleHit(last)['id'], 'end');
      }
      final all = await run('search_diaries', {'limit': 1});
      expect(all['total'], 5);
      expect(all['hasMore'], true);
      expect((all['hits'] as List).length, 1);
    },
  );

  test('search validates category, enum and range arguments', () async {
    for (final args in [
      {'categoryId': 'missing'},
      {'sort': 'random'},
      {'excerpt': 'short'},
      {'startDate': '2026-02-01', 'endDate': '2026-01-01'},
      {'mode': 'invalid'},
    ]) {
      await expectLater(
        client.toolCall('search_diaries', args),
        throwsA(isA<ToolArgumentException>()),
      );
    }
  });

  test('search excerpt projections and modified ordering', () async {
    final rich = jsonEncode({
      'type': 'doc',
      'content': [
        {
          'type': 'heading',
          'attrs': {'level': 1},
          'content': [
            {'type': 'text', 'text': 'Heading'},
          ],
        },
      ],
    });
    await diaries.insertDiaries([
      makeDiary(
        'rich',
        'Heading',
        content: rich,
      ).copyWith(lastModified: DateTime.utc(2030)),
      makeDiary('plain', 'Heading', time: DateTime.utc(2028)),
    ]);
    final marked = await run('search_diaries', {
      'query': 'Heading',
      'excerpt': 'markdown',
      'sort': 'modified',
    });
    expect((marked['hits'] as List).first['id'], 'rich');
    expect((marked['hits'] as List).first['preview'], contains('# Heading'));
    final none = await run('search_diaries', {'excerpt': 'none'});
    for (final hit in none['hits'] as List) {
      expect(hit, isNot(contains('excerpt')));
    }
  });

  test(
    'batch writes continue after per-item failures and return counts',
    () async {
      final created = await run('create_diary', {
        'items': [
          {'content': 'first', 'mood': 4},
          {'content': 'invalid category', 'categoryId': 'ghost'},
          {'content': 'last', 'mood': 'GREAT'},
        ],
      });
      expect(created['processed'], 3);
      expect(created['requested'], 3);
      final results = (created['results'] as List).cast<Map>();
      expect(results.map((item) => item['ok']), [true, false, true]);
      expect(results[1]['error'], contains('known category'));
      final id = results.first['diary']['id'] as String;
      final updated = await run('update_diary', {
        'items': [
          {'id': 'missing', 'title': 'bad'},
          {'id': id, 'title': 'changed'},
          {'id': id},
        ],
      });
      expect((updated['results'] as List).map((item) => item['ok']), [
        false,
        true,
        false,
      ]);
      final deleted = await run('delete_diary', {
        'ids': ['missing', id],
      });
      expect((deleted['results'] as List).map((item) => item['ok']), [
        false,
        true,
      ]);
      expect((await diaries.getDiaryByBusinessId(id))!.show, false);
      expect(
        (await diaries.getAllDiaries()).where((diary) => diary.show).length,
        1,
      );
    },
  );

  test(
    'call-wide schema failures execute no items and enforce batch limits',
    () async {
      for (final args in [
        <String, dynamic>{},
        {'items': []},
        {
          'items': [
            {'content': 1},
          ],
        },
        {
          'items': [
            {'title': 'no content'},
          ],
        },
        {
          'items': [
            for (var index = 0; index < 21; index++) {'content': 'overflow'},
          ],
        },
      ]) {
        await expectLater(
          client.toolCall('create_diary', args),
          throwsA(isA<ToolArgumentException>()),
        );
      }
      expect(await diaries.countAllDiaries(), 0);
      await expectLater(
        client.toolCall('get_diary', {'ids': List.filled(11, 'id')}),
        throwsA(isA<ToolArgumentException>()),
      );
      await expectLater(
        client.toolCall('delete_diary', {'ids': []}),
        throwsA(isA<ToolArgumentException>()),
      );
    },
  );

  test('updates preserve omitted fields and clear explicit nulls', () async {
    final category = await client.newCategory('Work');
    final created = row(
      await run('create_diary', {
        'items': [
          {
            'content': 'body',
            'title': 'Title',
            'mood': 'good',
            'tags': ['keep'],
            'categoryId': category,
            'time': '2026-01-15T08:30:00Z',
          },
        ],
      }),
    );
    final id = (created['diary'] as Map)['id'] as String;
    await run('update_diary', {
      'items': [
        {
          'id': id,
          'title': '',
          'mood': null,
          'tags': null,
          'categoryId': null,
          'content': null,
          'time': null,
        },
      ],
    });
    final diary = (await diaries.getDiaryByBusinessId(id))!;
    expect(diary.title, '');
    expect(diary.mood, null);
    expect(diary.categoryId, null);
    expect(diary.tags, isEmpty);
    expect(diary.contentText, 'body');
    expect(diary.time, DateTime.utc(2026, 1, 15, 8, 30));
    final failure = row(
      await run('update_diary', {
        'items': [
          {'id': id, 'categoryId': 'missing'},
        ],
      }),
    );
    expect(failure['ok'], false);
    expect((await diaries.getDiaryByBusinessId(id))!.categoryId, null);
  });

  test(
    'Markdown image read and rewrite preserve media and references',
    () async {
      await diaries.insertADiary(
        makeDiary(
          'photo',
          'caption',
          media: [
            {
              'type': 'image',
              'attrs': {'src': 'image-owned.png', 'alt': 'holiday'},
            },
          ],
        ),
      );
      final read = await run('get_diary', {
        'ids': ['photo', 'missing'],
      });
      expect(read['missing'], ['missing']);
      final full = (read['diaries'] as List).single as Map;
      final markdown = full['content'] as String;
      expect(markdown, contains('![holiday](image-owned.png)'));
      final updated = row(
        await run('update_diary', {
          'items': [
            {'id': 'photo', 'content': '$markdown\n\nNew ending.'},
          ],
        }),
      );
      expect(updated['ok'], true);
      expect((await diaries.getDiaryByBusinessId('photo'))!.imageName, [
        'image-owned.png',
      ]);
      expect(
        (await diaries.getDiaryByBusinessId('photo'))!.content,
        contains('image-owned.png'),
      );
      expect(diaryIdsIn(read), ['photo']);
      expect(
        diaryIdsIn({
          'results': [
            updated,
            {'ok': false, 'id': 'missing'},
          ],
        }),
        ['photo'],
      );
    },
  );

  test('get_diary surface formats, missing ids and body cap', () async {
    await diaries.insertDiaries([
      makeDiary('long', 'x' * 5000),
      makeDiary('hidden', 'secret', show: false),
    ]);
    final read = await run('get_diary', {
      'ids': ['long', 'hidden', 'unknown'],
      'contentFormat': 'document',
      'includeLinks': false,
    });
    expect(read['missing'], ['hidden', 'unknown']);
    expect((read['diaries'] as List).single['content'], isA<Map>());
    expect((read['diaries'] as List).single, isNot(contains('links')));
    final context = ToolContext(
      diaries: diaries,
      categories: categories,
      insights: MoodInsightsRepository(db),
      surface: ToolSurface.assistant,
    );
    final def = moodiaryTools.firstWhere((tool) => tool.name == 'get_diary');
    final assistant = await def.call({
      'ids': ['long'],
    }, context);
    expect(await def.output.validate(assistant.data), isEmpty);
    final full = (assistant.data['diaries'] as List).single as Map;
    expect(full, isNot(contains('links')));
    expect(full['truncated'], true);
    expect(full['fullLength'], 5000);
    expect((full['content'] as String).length, lessThanOrEqualTo(4000));
    await expectLater(
      def.call({
        'ids': ['long'],
        'contentFormat': 'text',
      }, context),
      throwsA(isA<ToolArgumentException>()),
    );
  });

  test('link graph retains forward, backward and dangling ids', () async {
    await diaries.insertDiaries([
      makeDiary('target', 'entry', tags: ['travel']),
      makeDiary(
        'source',
        'entry',
        tags: ['travel', 'food'],
        linkTo: ['target', 'ghost'],
      ),
      makeDiary('hidden', 'entry', tags: ['travel'], show: false),
    ]);
    final graph = await run('get_diary_links', {'id': 'source'});
    expect((graph['forward'] as List).single['id'], 'target');
    expect(graph['dangling'], ['ghost']);
    final backlinks = await run('get_diary_links', {'id': 'target'});
    expect((backlinks['backlinks'] as List).single['id'], 'source');
  });
}
