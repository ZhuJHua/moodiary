import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tool_definitions.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_assistant/src/data/impl/rig_assistant.dart';
import 'package:moodiary_assistant/src/data/memory_repository.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

void main() {
  late MoodiaryDatabase db;
  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    getIt.registerSingleton<DiaryRepository>(DiaryRepository(db));
    getIt.registerSingleton<TagRepository>(TagRepository(db));
    getIt.registerSingleton<CategoryRepository>(CategoryRepository(db));
    getIt.registerSingleton<MoodInsightsRepository>(MoodInsightsRepository(db));
    getIt.registerSingleton<MemoryRepository>(MemoryRepository(db));
  });
  tearDown(() async {
    await getIt.reset();
    await db.close();
  });
  Future<String> dispatch(String name, Object? args) => dispatchAssistantTool(
    spec: AssistantToolRegistry.byId(name),
    toolName: name,
    argsJson: jsonEncode(args),
  );

  test('dispatch validates and serializes compact JSON; malformed calls return Failed', () async {
    final out = await dispatch('create_diary', {
      'items': [
        {'content': 'Hello'},
      ],
    });
    expect(out, jsonEncode(jsonDecode(out)));
    expect(jsonDecode(out)['results'].single['ok'], true);
    expect(
      await dispatch('create_diary', {'items': []}),
      startsWith('Failed:'),
    );
    expect(
      await dispatch('get_diary', {'id': 'bad shape'}),
      startsWith('Failed:'),
    );
    expect(await dispatch('unknown', {}), 'Failed: unknown tool "unknown".');
    expect(
      await dispatchAssistantTool(
        spec: AssistantToolRegistry.byId('get_diary'),
        toolName: 'get_diary',
        argsJson: '[',
      ),
      startsWith('Failed:'),
    );
    expect(
      await dispatch('get_diary_links', {'id': 'missing'}),
      startsWith('Failed:'),
    );
  });

  test(
    'the assistant catalog shares definitions and filters current allowlists',
    () {
      final live = AssistantToolRegistry.specs.map((spec) => spec.id).toSet();
      expect(live, AssistantTool.values.map((tool) => tool.id).toSet());
      for (final tool in moodiaryTools.where(
        (def) => def.surfaces.contains(ToolSurface.assistant),
      )) {
        expect(
          identical(AssistantToolRegistry.byId(tool.name)!.definition, tool),
          true,
        );
      }
      expect(live, isNot(contains('read_diary_media')));
      expect(
        AssistantToolRegistry.specsFor(['get_diary', 'list_categories'])
            .map((spec) => spec.id),
        ['get_diary', 'list_categories'],
      );
      expect(
        toolIdsWithoutMemory().toSet().intersection({
          'recall_memory',
          'remember_fact',
          'forget_fact',
        }),
        isEmpty,
      );
    },
  );

  test('JSON summaries count completed results and support no-argument stored records', () {
    String summarize(String name, Map<String, Object?> data) =>
        AssistantToolRegistry.byId(name)!.summaryOf({}, jsonEncode(data));
    expect(
      summarize('get_diary', {
        'diaries': [
          {'id': 'a'},
        ],
        'missing': ['b'],
      }),
      l10n.assistant.toolRead(count: 1),
    );
    expect(
      summarize('search_diaries', {'total': 47, 'hits': []}),
      l10n.assistant.toolMatched(count: 47),
    );
    expect(
      summarize('create_diary', {
        'results': [
          {
            'ok': true,
            'diary': {'title': 'Saved'},
          },
        ],
      }),
      'Saved',
    );
    expect(
      summarize('update_diary', {
        'results': [
          {'ok': true},
          {'ok': false, 'error': 'missing'},
        ],
      }),
      l10n.assistant.toolBatchOutcome(succeeded: 1, failed: 1),
    );
    expect(summarize('run_javascript', {'value': '42'}), '42');
    expect(
      summarize('list_tags', {
        'tags': [
          {'tag': 'travel'},
        ],
      }),
      l10n.assistant.toolListed(count: 1),
    );
  });

  test('cached summaries follow language changes in stored records', () async {
    final locale = LocaleSettings.currentLocale;
    addTearDown(() => LocaleSettings.setLocale(locale));
    final call = AssistantToolCall(
      callId: 'read',
      name: 'get_diary',
      argsJson: '{}',
      result: jsonEncode({
        'diaries': [
          {'id': 'entry'},
        ],
      }),
      done: true,
    );
    for (final locale in [AppLocale.en, AppLocale.zh]) {
      await LocaleSettings.setLocale(locale);
      AssistantToolRegistry.prepare(call);
      expect(
        AssistantToolRegistry.summaryOf(call),
        l10n.assistant.toolRead(count: 1),
      );
      expect(
        AssistantToolRegistry.recordOf([call]),
        contains(l10n.assistant.toolRead(count: 1)),
      );
    }
  });

  test(
    'assistant-only definitions validate outputs and preserve memory behavior',
    () async {
      final context = assistantToolContext();
      Future<Map<String, Object?>> call(
        String name,
        Map<String, Object?> args,
      ) async {
        final def = assistantOnlyTools.firstWhere((tool) => tool.name == name);
        final result = await def.call(args, context);
        expect(await def.output.validate(result.data), isEmpty, reason: name);
        return result.data;
      }

      final remembered = await call('remember_fact', {
        'items': [
          {'text': 'Quiet replies', 'category': 'preference'},
          {'text': 'A goal', 'category': 'goal'},
        ],
      });
      final id = (remembered['results'] as List).first['id'];
      final duplicate = await call('remember_fact', {
        'items': [
          {'text': 'Quiet replies', 'category': 'preference'},
        ],
      });
      expect((duplicate['results'] as List).single['duplicate'], true);
      await call('remember_fact', {
        'items': [
          {'id': id, 'text': 'Revised', 'category': 'fact'},
        ],
      });
      final recall = await call('recall_memory', {});
      expect(recall['total'], 2);
      expect((recall['facts'] as List).length, 2);
      final forgotten = await call('forget_fact', {
        'ids': [id, 'missing'],
      });
      expect((forgotten['results'] as List).map((row) => row['ok']), [
        true,
        false,
      ]);
      final script = await call('run_javascript', {
        'code': 'console.log("hello"); 6 * 7',
      });
      expect(script['value'], '42');
      expect(script['logs'], ['[LOG] hello']);
      expect(
        await dispatch('run_javascript', {'code': '  '}),
        startsWith('Failed:'),
      );
    },
  );
}
