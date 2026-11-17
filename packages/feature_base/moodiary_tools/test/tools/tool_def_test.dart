import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import 'support.dart';

void main() {
  test(
    'schema failures name the field and skip parsing and execution',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final context = ToolContext(
        diaries: DiaryRepository(db),
        categories: CategoryRepository(db),
        insights: MoodInsightsRepository(db),
        surface: ToolSurface.assistant,
      );
      var parsed = false;
      var executed = false;
      final def = ToolDef<int, int>(
        name: 'bounded',
        title: 'Bounded',
        surfaces: const {ToolSurface.assistant},
        effect: ToolEffect.read,
        idempotent: true,
        description: (_) => 'A bounded test input.',
        input: (_) => Schema.fromMap({
          'type': 'object',
          'properties': {
            'limit': {'type': 'integer', 'minimum': 1},
          },
          'required': ['limit'],
        }),
        output: Schema.fromMap({
          'type': 'object',
          'properties': {
            'count': {'type': 'integer'},
          },
          'required': ['count'],
        }),
        parse: (raw) {
          parsed = true;
          return raw['limit']! as int;
        },
        run: (input, ctx) async {
          executed = true;
          expect(ctx.surface, ToolSurface.assistant);
          return input;
        },
        toJson: (output) => {'count': output},
      );
      await expectLater(
        def.call({'limit': 0}, context),
        throwsA(
          isA<ToolArgumentException>().having(
            (error) => error.message,
            'message',
            contains('limit'),
          ),
        ),
      );
      expect(parsed, isFalse);
      expect(executed, isFalse);
      final result = await def.call({'limit': 2}, context);
      expect(result.data, {'count': 2});
      expect(parsed, isTrue);
      expect(executed, isTrue);
    },
  );
}
