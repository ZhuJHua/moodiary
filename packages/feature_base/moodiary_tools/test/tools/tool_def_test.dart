import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import '../support.dart';

void main() {
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
