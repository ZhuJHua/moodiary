import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

void main() {
  String summaryOf(AssistantTool tool, Map<String, dynamic> input) =>
      AssistantToolRegistry.byId(tool.id)!.summaryOf(input, 'ok');

  group('工具卡片摘要', () {
    test('保存事实报事实原文', () {
      expect(
        summaryOf(.rememberFact, {
          'items': [
            {'category': 'preference', 'text': '别用感叹号'},
          ],
        }),
        '别用感叹号',
      );
    });

    test('写类工具不落进删除分支', () {
      const writeTools = [
        AssistantTool.createDiary,
        AssistantTool.updateDiary,
        AssistantTool.createCategory,
        AssistantTool.updateCategory,
        AssistantTool.rememberFact,
      ];
      for (final tool in writeTools) {
        expect(
          summaryOf(tool, const {
            'items': [<String, dynamic>{}],
          }),
          isNot(l10n.assistant.toolDeleted),
          reason: tool.id,
        );
      }
    });

    test('失败输出盖过各自的摘要', () {
      final spec = AssistantToolRegistry.byId(AssistantTool.rememberFact.id)!;
      expect(
        spec.summaryOf(const {
          'items': [
            {'category': 'preference', 'text': '别用感叹号'},
          ],
        }, 'Failed: nope'),
        l10n.assistant.toolFailed,
      );
    });
  });
}
