import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import '../support.dart';

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository diaries;
  late CategoryRepository categories;

  setUp(() {
    db = openTestDatabase();
    diaries = DiaryRepository(db);
    categories = CategoryRepository(db);
  });
  tearDown(() => db.close());

  Future<Map<String, Object?>> call(
    ToolSurface surface,
    String name,
    Map<String, Object?> args,
  ) async {
    final def = moodiaryTools.firstWhere((tool) => tool.name == name);
    final result = await def.call(
      args,
      ToolContext(
        tags: TagRepository(db),
        surface: surface,
        diaries: diaries,
        categories: categories,
        insights: MoodInsightsRepository(db),
      ),
    );
    expect(await def.output.validate(result.data), isEmpty, reason: name);
    return result.data;
  }

  Future<Map> update(Map<String, Object?> item) async =>
      ((await call(ToolSurface.assistant, 'update_diary', {
                    'items': [item],
                  }))['results']
                  as List)
              .single
          as Map;

  test('append then get_diary preserves the image reference', () async {
    await diaries.insertADiary(
      makeDiary(
        'photo',
        'Original',
        media: [
          {
            'type': 'image',
            'attrs': {'src': 'image-1.png', 'name': 'Photo'},
          },
        ],
      ),
    );
    expect(
      (await update({'id': 'photo', 'append': 'English translation'}))['ok'],
      true,
    );
    final read = await call(ToolSurface.assistant, 'get_diary', {
      'ids': ['photo'],
    });
    final body = (read['diaries'] as List).single['content'] as String;
    expect(body, contains('![Photo](image-1.png)'));
    expect(body, endsWith('English translation'));
  });

  test('rewrites require explicit removal for every media kind', () async {
    for (final (type, name) in [
      ('image', 'image-1.png'),
      ('audio', 'audio-1.mp3'),
      ('video', 'video-1.mp4'),
      ('attachment', 'file-1.pdf'),
    ]) {
      final original = makeDiary(
        type,
        'Original',
        media: [
          {
            'type': type,
            'attrs': {'src': name, 'name': 'Display name'},
          },
        ],
      );
      await diaries.insertADiary(original);
      final before = await diaries.getDiaryByBusinessId(type);
      final failed = await update({
        'id': type,
        'content': 'Replacement',
        'title': 'Changed',
      });
      expect(failed['ok'], false);
      expect(
        failed['error'],
        allOf(
          contains(name),
          contains('![name](src)'),
          contains('removeMedia'),
        ),
      );
      expect(await diaries.getDiaryByBusinessId(type), before);
      final removed = await update({
        'id': type,
        'content': 'Replacement',
        'removeMedia': [name],
      });
      expect(removed['ok'], true);
      final stored = (await diaries.getDiaryByBusinessId(type))!;
      expect([
        ...stored.imageName,
        ...stored.audioName,
        ...stored.videoName,
        ...stored.fileName,
      ], isEmpty);
      final read = await call(ToolSurface.assistant, 'get_diary', {
        'ids': [type],
      });
      expect((read['diaries'] as List).single['content'], 'Replacement');
    }
  });

  test(
    'unknown removal, missing content and mixed body edits fail per item',
    () async {
      final original = makeDiary('keep', 'Original');
      await diaries.insertADiary(original);
      final result = await call(ToolSurface.assistant, 'update_diary', {
        'items': [
          {
            'id': 'keep',
            'content': 'Rewrite',
            'removeMedia': ['unknown.png'],
          },
          {'id': 'keep', 'content': 'Rewrite', 'append': 'End'},
          {'id': 'keep', 'content': 'Rewrite', 'prepend': 'Start'},
          {'id': 'keep', 'title': 'Valid'},
        ],
      });
      final rows = result['results'] as List;
      expect(rows.map((row) => row['ok']), [false, false, false, true]);
      expect(rows.first['error'], contains('does not own: unknown.png'));
      expect(rows[1]['error'], contains('content cannot be combined'));
      expect(rows[2]['error'], contains('content cannot be combined'));
      expect(
        (await diaries.getDiaryByBusinessId('keep'))!.content,
        original.content,
      );
      await diaries.insertADiary(
        makeDiary(
          'photo',
          'Original',
          media: [
            {
              'type': 'image',
              'attrs': {'src': 'image-1.png'},
            },
          ],
        ),
      );
      final removal = await update({
        'id': 'photo',
        'removeMedia': ['image-1.png'],
      });
      expect(removal['ok'], false);
      expect(removal['error'], contains('removeMedia requires content'));
    },
  );

  for (final surface in ToolSurface.values) {
    Future<Map> update(Map<String, Object?> item) async =>
        ((await call(surface, 'update_diary', {
                      'items': [item],
                    }))['results']
                    as List)
                .single
            as Map;
    test(
      'body cap guards rewrites while permitting additions and metadata',
      () async {
        final cap = surface == ToolSurface.assistant
            ? assistantBodyChars
            : mcpResultChars;
        final body = '${'x' * (cap - 2)}🙂tail';
        final original = makeDiary('long', body);
        await diaries.insertADiary(original);
        final read = await call(surface, 'get_diary', {
          'ids': ['long'],
        });
        final projected = (read['diaries'] as List).single as Map;
        expect(projected['truncated'], true);
        expect(projected['content'], '${'x' * (cap - 2)}…');
        for (final (format, content) in [
          ('markdown', 'Short'),
          ('text', 'Short'),
          ('document', paragraphDoc('Short')),
        ]) {
          final failed = await update({
            'id': 'long',
            'content': content,
            'contentFormat': format,
          });
          expect(failed['ok'], false);
          expect(
            failed['error'],
            allOf(
              contains('$cap character read limit'),
              contains('append/prepend'),
            ),
          );
          expect(await diaries.getDiaryByBusinessId('long'), original);
        }
        expect((await update({'id': 'long', 'title': 'Long'}))['ok'], true);
        expect(
          (await update({
            'id': 'long',
            'append': 'End',
            'prepend': 'Start',
          }))['ok'],
          true,
        );
        expect(
          (await diaries.getDiaryByBusinessId('long'))!.contentText,
          'Start\n$body\nEnd',
        );
      },
    );
  }

  test(
    'assistant cap uses Markdown length and MCP can rewrite longer bodies',
    () async {
      await diaries.insertADiary(
        makeDiary('boundary', 'x' * assistantBodyChars),
      );
      final exact = await call(ToolSurface.assistant, 'update_diary', {
        'items': [
          {'id': 'boundary', 'content': 'Allowed'},
        ],
      });
      expect((exact['results'] as List).single['ok'], true);
      await diaries.insertADiary(
        makeDiary('long', 'x' * (assistantBodyChars + 1)),
      );
      final mcp = await call(ToolSurface.mcp, 'update_diary', {
        'items': [
          {'id': 'long', 'content': 'Allowed via MCP'},
        ],
      });
      expect((mcp['results'] as List).single['ok'], true);
      await diaries.insertADiary(
        makeDiary('escaped', '* ' * (assistantBodyChars ~/ 2)),
      );
      final escaped = await call(ToolSurface.assistant, 'update_diary', {
        'items': [
          {'id': 'escaped', 'content': 'Must fail'},
        ],
      });
      expect((escaped['results'] as List).single['ok'], false);
    },
  );
}
