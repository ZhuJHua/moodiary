import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';

void main() {
  group('工具 id 迁移', () {
    test('退役 id 各自映射并去重', () {
      expect(
        migrateAssistantToolIds([
          'queryDiaries',
          'semanticSearchDiaries',
          'listMemories',
          'updateMemory',
        ]),
        ['searchDiaries', 'recallMemory', 'rememberFact'],
      );
    });

    test('目标已在列表里时不会多出一条', () {
      expect(
        migrateAssistantToolIds(['rememberFact', 'updateMemory']),
        ['rememberFact'],
      );
    });

    test('保持顺序，未知 id 原样留着', () {
      expect(
        migrateAssistantToolIds(['getDiary', 'queryDiaries', 'whatIsThis']),
        ['getDiary', 'searchDiaries', 'whatIsThis'],
      );
    });

    test('映射表两端：新 id 活着，旧 id 已退役', () {
      final live = {for (final t in AssistantTool.values) t.id};
      for (final e in renamedAssistantToolIds.entries) {
        expect(live, contains(e.value), reason: '${e.value} 不在 AssistantTool 里');
        expect(live, isNot(contains(e.key)), reason: '${e.key} 还活着');
      }
    });

    test('迁移后的 id 都能被 specsFor 认出', () {
      final migrated = migrateAssistantToolIds([
        'queryDiaries',
        'semanticSearchDiaries',
        'listMemories',
        'updateMemory',
        'getDiary',
      ]);
      expect(
        AssistantToolRegistry.specsFor(migrated),
        hasLength(migrated.length),
      );
    });
  });
}
