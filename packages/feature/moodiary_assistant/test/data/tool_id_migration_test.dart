import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';

void main() {
  group('工具 id 迁移', () {
    test('两个搜索工具都映射到 searchDiaries，且去重', () {
      expect(
        migrateAssistantToolIds(['queryDiaries', 'semanticSearchDiaries']),
        ['searchDiaries'],
      );
    });

    test('listMemories → recallMemory，updateMemory → rememberFact', () {
      expect(migrateAssistantToolIds(['listMemories']), ['recallMemory']);
      expect(migrateAssistantToolIds(['updateMemory']), ['rememberFact']);
    });

    test('已经并存 rememberFact 时不会多出一条', () {
      expect(
        migrateAssistantToolIds(['rememberFact', 'updateMemory']),
        ['rememberFact'],
      );
    });

    test('保持顺序，未知 id 原样留着交给 specsFor 处理', () {
      expect(
        migrateAssistantToolIds(['getDiary', 'queryDiaries', 'whatIsThis']),
        ['getDiary', 'searchDiaries', 'whatIsThis'],
      );
    });

    test('映射表里的新 id 必须都真实存在', () {
      final live = {for (final t in AssistantTool.values) t.id};
      for (final target in renamedAssistantToolIds.values) {
        expect(live, contains(target), reason: '$target 不在 AssistantTool 里');
      }
    });

    test('映射表里的旧 id 必须都已经退役', () {
      final live = {for (final t in AssistantTool.values) t.id};
      for (final old in renamedAssistantToolIds.keys) {
        expect(live, isNot(contains(old)), reason: '$old 还活着，不该出现在迁移表');
      }
    });

    test('迁移后的 id 都能被 specsFor 认出来，不会静默变成空工具', () {
      final migrated = migrateAssistantToolIds([
        'queryDiaries',
        'semanticSearchDiaries',
        'listMemories',
        'updateMemory',
        'getDiary',
      ]);
      final specs = AssistantToolRegistry.specsFor(migrated);
      expect(specs, hasLength(migrated.length));
    });
  });
}
