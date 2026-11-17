import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import 'support.dart';

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
  late TestToolClient client;

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
    client = TestToolClient(
      ToolContext(
        diaries: diaries,
        categories: categories,
        insights: insights,
        surface: ToolSurface.mcp,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('keyword search', () {
    test('count and page share category and inclusive date filters', () async {
      final categoryId = await client.newCategory('Orchard');
      final start = DateTime.utc(2026, 1, 2);
      final end = DateTime.utc(2026, 1, 3);
      await diaries.insertDiaries([
        makeDiary(
          'before',
          'orchard',
          categoryId: categoryId,
          time: start.subtract(const Duration(microseconds: 1)),
        ),
        makeDiary('start', 'orchard', categoryId: categoryId, time: start),
        makeDiary('end', 'orchard', categoryId: categoryId, time: end),
        makeDiary(
          'after',
          'orchard',
          categoryId: categoryId,
          time: end.add(const Duration(microseconds: 1)),
        ),
        makeDiary('other-category', 'orchard', time: start),
        makeDiary(
          'hidden',
          'orchard',
          categoryId: categoryId,
          time: start,
          show: false,
        ),
      ]);
      for (var offset = 0; offset < 2; offset++) {
        final page = structuredOf(
          await client.toolCall('search_diaries', {
            'query': 'orchard',
            'categoryId': categoryId,
            'startDate': start.toIso8601String(),
            'endDate': end.toIso8601String(),
            'sort': 'oldest',
            'offset': offset,
            'limit': 1,
          }),
        );
        expect(page['total'], 2);
        expect(page['hasMore'], offset == 0);
        expect(singleHit(page)['id'], offset == 0 ? 'start' : 'end');
        expect(singleHit(page)['categoryName'], 'Orchard');
      }
    });

    test('paging retains exact totals and highlight markers', () async {
      await diaries.insertDiaries([
        for (var index = 0; index < 3; index++)
          makeDiary(
            'entry-$index',
            'orchard',
            title: 'orchard $index',
            time: DateTime.utc(2026, 1, index + 1),
          ),
      ]);
      final result = structuredOf(
        await client.toolCall('search_diaries', {
          'query': 'orchard',
          'sort': 'oldest',
          'offset': 1,
          'limit': 1,
        }),
      );
      expect(result.keys, [
        'query',
        'total',
        'offset',
        'limit',
        'hasMore',
        'hits',
      ]);
      expect(result['query'], 'orchard');
      expect(result['total'], 3);
      expect(result['offset'], 1);
      expect(result['limit'], 1);
      expect(result['hasMore'], isTrue);
      final hit = singleHit(result);
      expect(hit['id'], 'entry-1');
      expect(
        hit.keys,
        unorderedEquals([
          'id',
          'title',
          'time',
          'timeLocal',
          'lastModified',
          'categoryId',
          'categoryName',
          'mood',
          'tags',
          'excerpt',
          'show',
          'titleHighlight',
          'preview',
        ]),
      );
      expect(hit['titleHighlight'], '**orchard** 1');
      expect(hit['excerpt'], '**orchard**');
      expect(hit['preview'], 'orchard');

      final last = structuredOf(
        await client.toolCall('search_diaries', {
          'query': 'orchard',
          'sort': 'oldest',
          'offset': 2,
          'limit': 2,
        }),
      );
      expect(singleHit(last)['id'], 'entry-2');
      expect(last['total'], 3);
      expect(last['hasMore'], isFalse);

      final beyond = structuredOf(
        await client.toolCall('search_diaries', {
          'query': 'orchard',
          'offset': 10,
          'limit': 1,
        }),
      );
      expect(beyond['total'], 3);
      expect(beyond['hits'], isEmpty);
      expect(beyond['hasMore'], isFalse);
    });
  });

  group('diary tools', () {
    test('create_diary and get_diary round-trip metadata and body', () async {
      final categoryId = await client.newCategory('Journal');
      final created = structuredOf(
        await client.toolCall('create_diary', {
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
        await client.toolCall('get_diary', {
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

    test('create_diary always stores a visible diary', () async {
      final created = structuredOf(
        await client.toolCall('create_diary', {'content': 'new body'}),
      );
      expect((created['diary'] as Map)['show'], isTrue);
      final id = (created['diary'] as Map)['id'] as String;
      expect((await diaries.getDiaryByBusinessId(id))!.show, isTrue);
    });

    test('create_diary refuses a body that names media', () async {
      for (final arguments in <Map<String, dynamic>>[
        {'content': '![cat](image-abc.png)', 'contentFormat': 'markdown'},
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
      ]) {
        final response = await client.toolCall('create_diary', arguments);
        expect(errorCode(response), -32602);
        expect(errorMessage(response), contains('add_diary_image'));
      }
      expect(await diaries.countAllDiaries(), 0);
    });

    test('a recycled diary is hidden from every read and write tool', () async {
      await diaries.insertADiary(
        makeDiary('bin', 'hidden body', title: 'Hidden', show: false),
      );

      for (final response in [
        await client.toolCall('get_diary', {'id': 'bin'}),
        await client.toolCall('get_diary_links', {'id': 'bin'}),
        await client.toolCall('update_diary', {
          'id': 'bin',
          'title': 'changed',
        }),
      ]) {
        expect(resultOf(response)['isError'], isTrue);
        expect(textOf(response), contains('no diary with id="bin"'));
      }

      final stored = (await diaries.getDiaryByBusinessId('bin'))!;
      expect(stored.title, 'Hidden');
      expect(stored.show, isFalse);
    });

    test('update_diary refuses media the diary does not own', () async {
      await diaries.insertADiary(makeDiary('owner', 'body'));
      final response = await client.toolCall('update_diary', {
        'id': 'owner',
        'contentFormat': 'document',
        'content': jsonEncode({
          'type': 'doc',
          'attrs': {'v': 2},
          'content': [
            {
              'type': 'image',
              'attrs': {'src': 'image-someone-else.png'},
            },
          ],
        }),
      });
      expect(errorCode(response), -32602);
      expect(errorMessage(response), contains('add_diary_image'));

      final stored = (await diaries.getDiaryByBusinessId('owner'))!;
      expect(stored.imageName, isEmpty);
      expect(stored.contentText, 'body');
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
          await client.toolCall('update_diary', {
            'id': 'update-me',
            'title': 'After',
          }),
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

        await client.toolCall('update_diary', {
          'id': 'update-me',
          'content': 'new body',
        });
        after = (await diaries.getDiaryByBusinessId('update-me'))!;
        expect(after.title, 'After');
        expect(after.contentText, 'new body');
        expect(after.lastModified.isAfter(before.lastModified), isTrue);

        final read = structuredOf(
          await client.toolCall('get_diary', {'id': 'update-me'}),
        );
        expect(read['content'], 'new body');
      },
    );

    test(
      'update_diary clears nullable fields on null and keeps them on omission',
      () async {
        final categoryId = await client.newCategory('Keep me');
        await diaries.insertADiary(
          makeDiary(
            'nullable',
            'body',
            categoryId: categoryId,
            tags: ['one', 'two'],
          ),
        );
        await client.toolCall('update_diary', {
          'id': 'nullable',
          'mood': 'good',
        });

        final kept = structuredOf(
          await client.toolCall('update_diary', {
            'id': 'nullable',
            'title': 'Kept',
          }),
        );
        final keptSummary = kept['diary'] as Map<String, dynamic>;
        expect(keptSummary['categoryId'], categoryId);
        expect(keptSummary['mood'], 'good');
        expect(keptSummary['tags'], ['one', 'two']);

        final cleared = structuredOf(
          await client.toolCall('update_diary', {
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
          await client.toolCall('update_diary', {
            'id': 'nullable',
            'title': '',
          }),
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
          await client.toolCall('update_diary', {
            'id': 'solid',
            'title': 'New',
            'time': null,
          }),
        );
        final summary = updated['diary'] as Map<String, dynamic>;
        expect(summary['title'], 'New');
        expect(summary['show'], isTrue);
        expect(summary['time'], '2026-01-01T00:00:00.000Z');
      },
    );

    test('delete_diary recycles and preserves already recycled rows', () async {
      await diaries.insertDiaries([
        makeDiary('recycle-me', 'recycle body', title: 'Recycle'),
      ]);

      final recycled = structuredOf(
        await client.toolCall('delete_diary', {'id': 'recycle-me'}),
      );
      expect(recycled, {
        'deleted': true,
        'id': 'recycle-me',
        'title': 'Recycle',
      });
      final first = (await diaries.getDiaryByBusinessId('recycle-me'))!;
      expect(first.show, isFalse);

      // Recycling an already recycled diary does not write the row again.
      final again = structuredOf(
        await client.toolCall('delete_diary', {'id': 'recycle-me'}),
      );
      expect(again['alreadyRecycled'], isTrue);
      final second = (await diaries.getDiaryByBusinessId('recycle-me'))!;
      expect(second.lastModified, first.lastModified);

      final ghost = await client.toolCall('delete_diary', {'id': 'ghost'});
      expect(resultOf(ghost)['isError'], isTrue);
      expect(textOf(ghost), contains('no diary with id="ghost"'));
    });

    test('search_diaries finds body words and handles no hits', () async {
      await diaries.insertDiaries([
        makeDiary('apple', 'apple pie recipe', title: 'Food'),
        makeDiary('banana', 'banana bread recipe', title: 'Baking'),
      ]);

      final found = structuredOf(
        await client.toolCall('search_diaries', {'query': 'apple'}),
      );
      expect(found['total'], 1);
      expect(found['query'], 'apple');
      final hit = singleHit(found);
      expect(hit['id'], 'apple');
      expect(hit['excerpt'] as String, contains('**apple**'));

      final missing = structuredOf(
        await client.toolCall('search_diaries', {'query': 'zzzz'}),
      );
      expect(missing['total'], 0);
      expect(missing['hits'], isEmpty);
    });

    test('search_diaries sorts by time on request', () async {
      await diaries.insertDiaries([
        makeDiary(
          'older',
          'apple older',
          title: 'apple',
          time: DateTime.utc(2020, 1, 1),
        ),
        makeDiary('newer', 'apple newer', time: DateTime.utc(2026, 1, 1)),
      ]);

      List<String> ids(Map<String, dynamic> data) => [
        for (final hit in (data['hits'] as List).cast<Map<String, dynamic>>())
          hit['id'] as String,
      ];

      final newest = structuredOf(
        await client.toolCall('search_diaries', {
          'query': 'apple',
          'sort': 'newest',
        }),
      );
      expect(ids(newest), ['newer', 'older']);

      final oldest = structuredOf(
        await client.toolCall('search_diaries', {
          'query': 'apple',
          'sort': 'oldest',
        }),
      );
      expect(ids(oldest), ['older', 'newer']);

      final relevance = structuredOf(
        await client.toolCall('search_diaries', {'query': 'apple'}),
      );
      expect(ids(relevance), ['older', 'newer']);
      final explicitRelevance = structuredOf(
        await client.toolCall('search_diaries', {
          'query': 'apple',
          'sort': 'relevance',
        }),
      );
      expect(ids(explicitRelevance), ids(relevance));
    });

    test(
      'list_diaries pages, sorts and filters by category and time',
      () async {
        final categoryId = await client.newCategory('Logs');
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
          await client.toolCall('list_diaries', {'limit': 2, 'offset': 1}),
        );
        expect(diaryIds(page), ['d4', 'd3']);
        expect(page['count'], 2);
        expect(page['offset'], 1);
        expect(page['limit'], 2);
        expect(page['hasMore'], isTrue);

        final ascending = structuredOf(
          await client.toolCall('list_diaries', {'limit': 3, 'sort': 'oldest'}),
        );
        expect(diaryIds(ascending), ['d1', 'd2', 'd3']);

        final byCategory = structuredOf(
          await client.toolCall('list_diaries', {'categoryId': categoryId}),
        );
        expect(diaryIds(byCategory), ['d2', 'd1']);
        expect([
          for (final diary
              in (byCategory['diaries'] as List).cast<Map<String, dynamic>>())
            diary['categoryId'],
        ], everyElement(categoryId));

        final byWindow = structuredOf(
          await client.toolCall('list_diaries', {
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
        await client.toolCall('list_diaries', {'tag': 'work', 'limit': 1}),
      );
      expect(diaryIds(first), ['t4']);
      expect(first['hasMore'], isTrue);

      final second = structuredOf(
        await client.toolCall('list_diaries', {
          'tag': 'work',
          'limit': 1,
          'offset': 1,
        }),
      );
      expect(diaryIds(second), ['t2']);
      expect(second['hasMore'], isFalse);

      final unknownTag = structuredOf(
        await client.toolCall('list_diaries', {'tag': 'missing'}),
      );
      expect(unknownTag['diaries'], isEmpty);
      expect(unknownTag['hasMore'], isFalse);

      final categoryId = await client.newCategory('Tagged');
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
        await client.toolCall('list_diaries', {
          'tag': 'work',
          'categoryId': categoryId,
        }),
      );
      expect(diaryIds(scoped), ['t6']);
    });

    test(
      'list_diaries and search_diaries reject an unknown category',
      () async {
        await diaries.insertADiary(makeDiary('known', 'body'));

        final listed = await client.toolCall('list_diaries', {
          'categoryId': 'ghost',
        });
        expect(errorCode(listed), -32602);
        expect(errorMessage(listed), contains('not a known category'));
        expect(errorMessage(listed), contains('list_categories'));

        final searched = await client.toolCall('search_diaries', {
          'query': 'body',
          'categoryId': 'ghost',
        });
        expect(errorCode(searched), -32602);
        expect(errorMessage(searched), contains('list_categories'));

        // The same id on a write is already an invalid params error.
        final created = await client.toolCall('create_diary', {
          'content': 'body',
          'categoryId': 'ghost',
        });
        expect(errorCode(created), -32602);
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
        await client.toolCall('get_diary', {'id': 'source'}),
      );
      expect(withLinks['contentFormat'], 'markdown');
      expect(withLinks['content'], contains('[L](moodiary://diary/target)'));
      expect((withLinks['links'] as Map)['forward'], hasLength(1));

      final labelOnly = structuredOf(
        await client.toolCall('get_diary', {
          'id': 'source',
          'linkStyle': 'label',
        }),
      );
      expect(labelOnly['content'], 'see L');
      expect(labelOnly['content'], isNot(contains('moodiary://diary/')));

      final plain = structuredOf(
        await client.toolCall('get_diary', {
          'id': 'source',
          'contentFormat': 'text',
        }),
      );
      expect(plain['contentFormat'], 'text');
      expect(plain['content'], 'see L (moodiary://diary/target)');

      final plainLabel = structuredOf(
        await client.toolCall('get_diary', {
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
        await client.toolCall('get_diary', {'id': 'rich'}),
      );
      expect(markdown['contentFormat'], 'markdown');
      expect(markdown['content'], contains('# Heading'));
      expect(markdown['content'], contains('**bold words**'));

      final plain = structuredOf(
        await client.toolCall('get_diary', {
          'id': 'rich',
          'contentFormat': 'text',
        }),
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
          await client.toolCall('get_diary', {
            'id': 'rich',
            'contentFormat': 'document',
          }),
        );
        expect(raw['contentFormat'], 'document');
        expect(raw['content'], isA<Map>());
        expect((raw['content'] as Map)['type'], 'doc');
        expect(raw['contentTruncated'], isFalse);

        final created = structuredOf(
          await client.toolCall('create_diary', {
            'title': 'Document',
            'content': richDocument(),
            'contentFormat': 'document',
          }),
        );
        final id = (created['diary'] as Map)['id'] as String;
        final stored = (await diaries.getDiaryByBusinessId(id))!;
        expect(stored.type, 'tiptap');
        expect(docBlocks(storedDoc(stored.content)).first['type'], 'heading');

        await client.toolCall('update_diary', {
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

        final invalid = await client.toolCall('create_diary', {
          'content': '{"type":"paragraph"}',
          'contentFormat': 'document',
        });
        expect(errorCode(invalid), -32602);
        expect(errorMessage(invalid), contains('Tiptap document'));
      },
    );

    test('create_diary contentFormat picks Markdown or plain text', () async {
      final markdown = structuredOf(
        await client.toolCall('create_diary', {
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
        await client.toolCall('get_diary', {
          'id': (markdown['diary'] as Map)['id'] as String,
        }),
      );
      expect(markdownRead['content'], contains('# Heading'));
      expect(markdownRead['content'], contains('- one'));

      final text = structuredOf(
        await client.toolCall('create_diary', {
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

      await client.toolCall('update_diary', {
        'id': 'edit',
        'content': '## Later',
      });
      var stored = (await diaries.getDiaryByBusinessId('edit'))!;
      expect(docBlocks(storedDoc(stored.content)).single['type'], 'heading');

      await client.toolCall('update_diary', {
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

        final plain = structuredOf(await client.toolCall('list_diaries'));
        expect(singleSummary(plain)['excerpt'], 'Heading bold words');

        final marked = structuredOf(
          await client.toolCall('list_diaries', {'excerpt': 'markdown'}),
        );
        final excerpt = singleSummary(marked)['excerpt'] as String;
        expect(excerpt, contains('# Heading'));
        expect(excerpt, contains('**bold words**'));

        final none = structuredOf(
          await client.toolCall('list_diaries', {'excerpt': 'none'}),
        );
        expect(singleSummary(none), isNot(contains('excerpt')));
      },
    );

    test('search_diaries excerpt=markdown projects the preview', () async {
      await diaries.insertADiary(
        makeDiary('apple-doc', 'apple\nnote', content: richDocument()),
      );

      final plain = structuredOf(
        await client.toolCall('search_diaries', {'query': 'Heading'}),
      );
      expect(singleHit(plain)['preview'], 'Heading bold words');
      expect(singleHit(plain)['excerpt'], contains('**Heading**'));

      final marked = structuredOf(
        await client.toolCall('search_diaries', {
          'query': 'Heading',
          'excerpt': 'markdown',
        }),
      );
      expect(singleHit(marked)['preview'], contains('# Heading'));

      // The highlight snippet is the point of the search, so excerpt=none only
      // drops the preview.
      final none = structuredOf(
        await client.toolCall('search_diaries', {
          'query': 'Heading',
          'excerpt': 'none',
        }),
      );
      expect(singleHit(none), isNot(contains('preview')));
      expect(singleHit(none)['excerpt'], contains('**Heading**'));
    });
  });

  group('categories and statistics', () {
    test('category tools use each category own count', () async {
      final work = await client.newCategory('Work');
      expect((await categories.getCategoryById(work))!.parentId, isNull);
      final projects = Category.create(
        categoryName: 'Projects',
        parentId: work,
      );
      await categories.insertACategory(projects);
      await diaries.insertDiaries([
        makeDiary('work', 'one', categoryId: work),
        makeDiary('project-1', 'two', categoryId: projects.id),
        makeDiary('project-2', 'three', categoryId: projects.id),
        makeDiary('hidden', 'four', categoryId: work, show: false),
      ]);

      final listed = structuredOf(await client.toolCall('list_categories'));
      expect(listed['total'], 2);
      final all = (listed['categories'] as List).cast<Map<String, dynamic>>();
      expect(all, hasLength(2));
      expect(
        all.singleWhere((category) => category['id'] == work)['diaries'],
        1,
      );
      expect(
        all.singleWhere((category) => category['id'] == projects.id)['diaries'],
        2,
      );
    });

    test('delete_category leaves existing child rows untouched', () async {
      final work = await client.newCategory('Work');
      final projects = Category.create(
        categoryName: 'Projects',
        parentId: work,
      );
      await categories.insertACategory(projects);

      final removed = structuredOf(
        await client.toolCall('delete_category', {'id': work}),
      );

      expect(removed['deleted'], isTrue);
      expect(removed.keys, unorderedEquals(['deleted', 'id', 'name']));
      expect(await categories.getCategoryById(work), isNull);
      expect(await categories.getCategoryById(projects.id), projects);
    });

    test('category tools list, rename and refuse non-empty delete', () async {
      final work = await client.newCategory('Work');
      final projects = await client.newCategory('Projects');
      final empty = await client.newCategory('Temp');

      var listed = structuredOf(await client.toolCall('list_categories'));
      expect(listed['total'], 3);
      final all = (listed['categories'] as List).cast<Map<String, dynamic>>();
      expect(all, hasLength(3));
      expect(
        all.firstWhere((category) => category['id'] == work)['diaries'],
        0,
      );
      expect(all.map((category) => category['id']), contains(projects));
      for (final category in all) {
        expect(
          category.keys,
          unorderedEquals([
            'id',
            'name',
            'color',
            'colorHex',
            'lastModified',
            'diaries',
          ]),
        );
      }

      final renamed = structuredOf(
        await client.toolCall('update_category', {
          'id': projects,
          'name': 'Projects 2026',
        }),
      );
      expect(renamed['updated'], isTrue);
      expect((renamed['category'] as Map)['name'], 'Projects 2026');

      listed = structuredOf(await client.toolCall('list_categories'));
      final renamedNode = (listed['categories'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((category) => category['id'] == projects);
      expect(renamedNode['name'], 'Projects 2026');

      final removed = structuredOf(
        await client.toolCall('delete_category', {'id': empty}),
      );
      expect(removed['deleted'], isTrue);
      expect(removed['id'], empty);
      expect(removed.keys, unorderedEquals(['deleted', 'id', 'name']));
      expect(await categories.getCategoryById(empty), isNull);

      await diaries.insertADiary(
        makeDiary('busy-diary', 'stays', categoryId: projects),
      );
      final refused = structuredOf(
        await client.toolCall('delete_category', {'id': projects}),
      );
      expect(refused['deleted'], isFalse);
      expect(refused['id'], projects);
      expect(
        refused.keys,
        unorderedEquals(['deleted', 'id', 'name', 'reason']),
      );
      expect(refused['reason'] as String, isNotEmpty);
      expect(await categories.getCategoryById(projects), isNotNull);
    });

    test('colour accepts an ARGB integer and both hex forms', () async {
      final fromInt = structuredOf(
        await client.toolCall('create_category', {
          'name': 'Int',
          'color': 0xFF112233,
        }),
      );
      final intCategory = fromInt['category'] as Map<String, dynamic>;
      expect(intCategory['color'], 0xFF112233);
      expect(intCategory['colorHex'], '#FF112233');

      final fromRgb = structuredOf(
        await client.toolCall('create_category', {
          'name': 'RGB',
          'color': '#3366CC',
        }),
      );
      final rgbCategory = fromRgb['category'] as Map<String, dynamic>;
      expect(rgbCategory['color'], 0xFF3366CC);
      expect(rgbCategory['colorHex'], '#FF3366CC');

      final fromArgb = structuredOf(
        await client.toolCall('create_category', {
          'name': 'ARGB',
          'color': '#80112233',
        }),
      );
      final argbCategory = fromArgb['category'] as Map<String, dynamic>;
      expect(argbCategory['color'], 0x80112233);
      expect(argbCategory['colorHex'], '#80112233');
    });

    test('an empty string or null clears the colour', () async {
      final id = await client.newCategory('Clearable', color: 0xFF445566);

      final clearedByEmpty = structuredOf(
        await client.toolCall('update_category', {'id': id, 'color': ''}),
      );
      expect((clearedByEmpty['category'] as Map)['color'], isNull);
      expect((clearedByEmpty['category'] as Map)['colorHex'], isNull);
      expect((await categories.getCategoryById(id))!.color, isNull);

      await client.toolCall('update_category', {'id': id, 'color': '#00FF00'});
      expect((await categories.getCategoryById(id))!.color, 0xFF00FF00);

      final clearedByNull = structuredOf(
        await client.toolCall('update_category', {'id': id, 'color': null}),
      );
      expect((clearedByNull['category'] as Map)['color'], isNull);

      // Omitting the field leaves the stored colour alone.
      await client.toolCall('update_category', {'id': id, 'color': '#0000FF'});
      final renamed = structuredOf(
        await client.toolCall('update_category', {'id': id, 'name': 'Renamed'}),
      );
      expect((renamed['category'] as Map)['color'], 0xFF0000FF);
    });

    test('a wrong colour value explains the accepted forms', () async {
      final id = await client.newCategory('Wrong colour');
      final response = await client.toolCall('update_category', {
        'id': id,
        'color': 'red',
      });
      expect(errorCode(response), -32602);
      final message = errorMessage(response);
      expect(message, contains('#RRGGBB'));
      expect(message, contains('#AARRGGBB'));
      expect(message, contains('empty string'));
    });

    test('update_category preserves the stored parent', () async {
      final parent = await client.newCategory('Root');
      final category = Category.create(categoryName: 'Child', parentId: parent);
      await categories.insertACategory(category);

      final kept = structuredOf(
        await client.toolCall('update_category', {
          'id': category.id,
          'name': 'Child 2',
        }),
      );
      expect((kept['category'] as Map)['name'], 'Child 2');
      expect((await categories.getCategoryById(category.id))!.parentId, parent);
    });

    test(
      'update_category requires changes and reports a missing target',
      () async {
        final category = await client.newCategory('Work');
        final unchanged = await client.toolCall('update_category', {
          'id': category,
        });
        expect(errorCode(unchanged), -32602);
        expect(
          errorMessage(unchanged),
          contains('at least one of name, color'),
        );

        final missingTarget = await client.toolCall('update_category', {
          'id': 'ghost',
          'name': 'Renamed',
        });
        expect(resultOf(missingTarget)['isError'], isTrue);
        expect(textOf(missingTarget), contains('no category with id="ghost"'));
      },
    );

    test('get_stats reports totals and per-category counts', () async {
      final work = await client.newCategory('Work');
      final life = await client.newCategory('Life');
      await diaries.insertDiaries([
        makeDiary('w1', 'one', categoryId: work),
        makeDiary('l1', 'two', categoryId: life),
        makeDiary('l2', 'three', categoryId: life),
        makeDiary('hidden', 'four', categoryId: work, show: false),
      ]);

      final stats = structuredOf(await client.toolCall('get_stats'));
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

      final tags = structuredOf(await client.toolCall('list_tags'));
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
          await client.toolCall('get_diary_links', {'id': 'source-a'}),
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
          await client.toolCall('get_diary_links', {'id': 'target'}),
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
          await client.toolCall('get_diary_links', {'id': 'source-b'}),
        );
        expect(dangling['dangling'], ['ghost']);
      },
    );
  });

  group('invalid arguments', () {
    test('bad calls fail with protocol or tool level errors', () async {
      final missingContent = await client.toolCall('create_diary', {
        'title': 'No body',
      });
      expect(errorCode(missingContent), -32602);
      expect(missingContent.containsKey('result'), isFalse);

      final unknownGet = await client.toolCall('get_diary', {'id': 'ghost'});
      expect(resultOf(unknownGet)['isError'], isTrue);
      expect(textOf(unknownGet), contains('no diary with id="ghost"'));

      final unknownUpdate = await client.toolCall('update_diary', {
        'id': 'ghost',
        'title': 'x',
      });
      expect(resultOf(unknownUpdate)['isError'], isTrue);

      await diaries.insertADiary(makeDiary('known', 'body'));
      final noFields = await client.toolCall('update_diary', {'id': 'known'});
      expect(errorCode(noFields), -32602);

      // An explicit null on every nullable field is still a real change.
      final clearedOnly = await client.toolCall('update_diary', {
        'id': 'known',
        'tags': null,
      });
      expect(resultOf(clearedOnly)['isError'] ?? false, isFalse);

      final unknownFormat = await client.toolCall('create_diary', {
        'content': 'body',
        'contentFormat': 'html',
      });
      expect(errorCode(unknownFormat), -32602);

      final unknownExcerpt = await client.toolCall('list_diaries', {
        'excerpt': 'short',
      });
      expect(errorCode(unknownExcerpt), -32602);

      final reversedRange = await client.toolCall('list_diaries', {
        'startDate': '2026-02-01',
        'endDate': '2026-01-01',
      });
      expect(errorCode(reversedRange), -32602);
      expect(errorMessage(reversedRange), contains('startDate'));
    });
  });
}
