import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_mcp/src/tools/register_moodiary_tools.dart';
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
  late McpServer server;
  late TestMcpClient client;
  late Directory mediaRoot;

  setUpAll(() {
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
  });

  setUp(() {
    mediaRoot = Directory.systemTemp.createTempSync('mcp-protocol-');
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    diaries = DiaryRepository(db);
    categories = CategoryRepository(db);
    insights = MoodInsightsRepository(db);
    server = buildMoodiaryServer(
      iconUri: Uri.parse('http://127.0.0.1/icon.png'),
      diaries: diaries,
      categories: categories,
      insights: insights,
      appVersion: 'test',
      mediaStore: DiaryMediaStore(
        pathOf: (kind, name) => '${mediaRoot.path}/$kind/$name',
      ),
    );
    client = TestMcpClient(server: server);
  });

  tearDown(() async {
    await client.close();
    await db.close();
    await mediaRoot.delete(recursive: true);
  });

  test(
    'tool calls keep JSON content, output schemas and error tiers',
    () async {
      final listed = resultOf(await client.call('tools/list'));
      for (final def in moodiaryTools) {
        expect(toolNamed(listed, def.name)['outputSchema'], def.output.value);
      }
      final created = await client.toolCall('create_diary', {
        'content': 'Protocol sample',
      });
      final data = structuredOf(created);
      expect(jsonDecode(textOf(created)), data);
      final id = (data['diary'] as Map)['id'];
      expect(
        structuredOf(await client.toolCall('get_diary', {'id': id}))['id'],
        id,
      );
      expect(
        errorCode(await client.toolCall('get_diary', {})),
        ErrorCode.invalidParams.value,
      );
      final unknown = await client.toolCall('get_diary', {'id': 'unknown'});
      expect(resultOf(unknown)['isError'], isTrue);
      expect(unknown.containsKey('error'), isFalse);
    },
  );

  test('media results keep image before JSON metadata', () async {
    final bytes = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    final file = File('${mediaRoot.path}/image/sample.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    await diaries.insertADiary(
      makeDiary(
        'image-diary',
        'Protocol image',
        media: [
          {
            'type': 'image',
            'attrs': {'src': 'sample.png'},
          },
        ],
      ).copyWith(
        weather: const DiaryWeather(icon: '100', text: 'Sunny'),
      ),
    );
    final response = await client.toolCall('read_diary_media', {
      'id': 'image-diary',
      'name': 'sample.png',
    });
    final content = contentOf(response);
    expect(content.map((item) => item['type']), ['image', 'text']);
    expect(base64Decode(content.first['data'] as String), bytes);
    expect(jsonDecode(content.last['text'] as String), structuredOf(response));
    final diary = structuredOf(
      await client.toolCall('get_diary', {'id': 'image-diary'}),
    );
    expect((diary['weather'] as Map)['temp'], isNull);
  });

  group('catalog', () {
    test('initialize then tools/list returns the full catalog', () async {
      await client.connect();
      expect(client.sdk.getServerVersion()!.version, 'test');

      final listed = resultOf(await client.call('tools/list'));
      final tools = (listed['tools'] as List).cast<Map<String, dynamic>>();
      expect(
        (toolNamed(listed, 'update_diary')['annotations']
            as Map)['destructiveHint'],
        isTrue,
      );
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
      final listed = resultOf(await client.call('tools/list'));

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
      ]);
      final writeFormat = propertiesOf(
        toolNamed(listed, 'create_diary'),
      )['contentFormat'];
      expect((writeFormat as Map)['enum'], ['markdown', 'text', 'document']);

      expect(propertiesOf(toolNamed(listed, 'delete_diary')).keys, ['id']);

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
      ]);
      expect(propertiesOf(toolNamed(listed, 'create_category')).keys, [
        'name',
        'color',
      ]);
    });

    test('the tool descriptions explain the clearing rule', () async {
      final listed = resultOf(await client.call('tools/list'));
      final update = toolNamed(listed, 'update_diary')['description'] as String;
      expect(update, contains('Send null'));
      expect(update, contains('unchanged'));
      final colour = propertiesOf(
        toolNamed(listed, 'create_category'),
      )['color'];
      expect((colour as Map)['description'] as String, contains('#AARRGGBB'));
    });
  });

  group('prompts and completions', () {
    test('prompt instructions use registered tool argument names', () async {
      await diaries.insertADiary(makeDiary('p1', 'prompt body'));
      final listedTools = resultOf(await client.call('tools/list'));
      final tools = (listedTools['tools'] as List).cast<Map<String, dynamic>>();
      final schemas = {
        for (final tool in tools) tool['name'] as String: propertiesOf(tool),
      };
      final toolPattern = RegExp(
        '\\b(?:${schemas.keys.map(RegExp.escape).join('|')})\\b',
      );
      final keyPattern = RegExp(r'\b([a-zA-Z]\w*)\s*=');
      final listedPrompts = resultOf(await client.call('prompts/list'));
      const values = {
        'date': '2026-01-15',
        'start': '2026-01-01',
        'end': '2026-01-31',
        'diaryId': 'p1',
      };

      for (final prompt in listedPrompts['prompts'] as List) {
        final rendered = resultOf(
          await client.call('prompts/get', {
            'name': prompt['name'],
            'arguments': {
              for (final argument in prompt['arguments'] as List? ?? [])
                argument['name'] as String: values[argument['name']],
            },
          }),
        );
        var checked = 0;
        for (final message in rendered['messages'] as List) {
          final text = message['content']['text'] as String;
          final instructions = toolPattern.allMatches(text).toList();
          for (var index = 0; index < instructions.length; index++) {
            final instruction = instructions[index];
            final tool = instruction.group(0)!;
            final end = index + 1 < instructions.length
                ? instructions[index + 1].start
                : text.length;
            final arguments = text
                .substring(instruction.end, end)
                .split('\n')
                .first;
            for (final key in keyPattern.allMatches(arguments)) {
              expect(
                schemas[tool],
                contains(key.group(1)),
                reason: '${prompt['name']}: $tool with ${key.group(1)}',
              );
              checked++;
            }
          }
        }
        expect(checked, greaterThan(0), reason: '${prompt['name']}');
      }
    });

    test('prompts render messages and complete known values', () async {
      await diaries.insertADiary(
        makeDiary('p1', 'prompt body', time: DateTime(2020, 1, 15, 12)),
      );

      final daily = resultOf(
        await client.call('prompts/get', {
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
        await client.call('prompts/get', {
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
        await client.call('completion/complete', {
          'ref': {'type': 'ref/prompt', 'name': 'daily_review'},
          'argument': {'name': 'date', 'value': '2020-01-1'},
        }),
      );
      expect(dates, contains('2020-01-15'));
      expect(dates.every((value) => value.startsWith('2020-01')), isTrue);
    });
  });
}
