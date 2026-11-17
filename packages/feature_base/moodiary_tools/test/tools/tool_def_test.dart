import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import '../support.dart';

void main() {
  test('per-call tiers default to the static effect', () {
    for (final tool in moodiaryTools.where(
      (tool) => !{'update_diary', 'delete_diary'}.contains(tool.name),
    )) {
      expect(tool.tierOf(const {}), tool.effect, reason: tool.name);
    }
  });

  test('get_diary shares its schema, description and graph default', () {
    final tool = moodiaryTools.firstWhere((tool) => tool.name == 'get_diary');
    expect(
      tool.input(ToolSurface.assistant).value,
      tool.input(ToolSurface.mcp).value,
    );
    expect(
      tool.description(ToolSurface.assistant),
      tool.description(ToolSurface.mcp),
    );
    for (final surface in ToolSurface.values) {
      final properties = tool.input(surface).value['properties'] as Map;
      expect(
        properties.keys,
        unorderedEquals(['ids', 'contentFormat', 'linkStyle', 'includeLinks']),
      );
      expect(
        ((properties['includeLinks'] as Map)['anyOf'] as List).first['default'],
        false,
      );
    }
  });

  test(
    'schema failures skip writes and schemas are cached per surface',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final context = ToolContext(
        diaries: DiaryRepository(db),
        categories: CategoryRepository(db),
        insights: MoodInsightsRepository(db),
        surface: ToolSurface.assistant,
      );
      final tool = toolsFor(ToolSurface.assistant)
          .firstWhere((tool) => tool.name == 'create_diary');
      for (final value in [null, 42, true, <String>[]]) {
        await expectLater(
          tool.call({
            'items': [
              {'content': value},
            ],
          }, context),
          throwsA(
            isA<ToolArgumentException>().having(
              (error) => error.message,
              'message',
              contains('content'),
            ),
          ),
        );
      }
      expect(await context.diaries.countAllDiaries(), 0);
      final result = await tool.call({
        'items': [
          {'content': 'Saved'},
        ],
      }, context);
      expect((result.data['results'] as List).single['ok'], true);
      for (final surface in ToolSurface.values) {
        expect(identical(tool.input(surface), tool.input(surface)), true);
      }
    },
  );
}
