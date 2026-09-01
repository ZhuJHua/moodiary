import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';

void main() {
  group('AssistantToolRegistry.specsFor', () {
    test('null = 全部（含未来新增的语义由 null 承担）', () {
      expect(AssistantToolRegistry.specsFor(null), AssistantToolRegistry.specs);
    });

    test('空列表 = 一个都不挂', () {
      expect(AssistantToolRegistry.specsFor(const []), isEmpty);
    });

    test('子集按 specs 原顺序过滤，与传入顺序无关', () {
      final allowed = [
        AssistantTool.rememberFact.id,
        AssistantTool.queryDiaries.id,
      ];
      final ids = [
        for (final s in AssistantToolRegistry.specsFor(allowed)) s.id,
      ];
      // specs 里 queryDiaries 在 rememberFact 之前。
      expect(ids, [
        AssistantTool.queryDiaries.id,
        AssistantTool.rememberFact.id,
      ]);
    });

    test('未知 id 静默忽略（预设可能存着已下线工具的 id）', () {
      final specs = AssistantToolRegistry.specsFor([
        'gone-tool',
        AssistantTool.getDiary.id,
      ]);
      expect(specs.single.id, AssistantTool.getDiary.id);
    });
  });
}
