import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

void main() {
  String summaryOf(AssistantTool tool, Map<String, dynamic> input) {
    final spec = AssistantToolRegistry.byId(tool.id)!;
    return spec.summaryOf(input, 'ok');
  }

  group('工具卡片摘要', () {
    test('保存事实报事实原文，不是「已删除」', () {
      final text = summaryOf(.rememberFact, {
        'items': [
          {'category': 'preference', 'text': '别用感叹号'},
        ],
      });
      expect(text, '别用感叹号');
      expect(text, isNot(l10n.assistant.toolDeleted));
    });

    test('忘掉事实才报已删除', () {
      expect(
        summaryOf(.forgetFact, {
          'items': [
            {'id': 'f1'},
          ],
        }),
        l10n.assistant.toolDeleted,
      );
    });

    test('删除分类报已删除', () {
      expect(
        summaryOf(.deleteCategory, {
          'ids': ['c1'],
        }),
        l10n.assistant.toolDeleted,
      );
    });

    test('创建日记报标题', () {
      expect(
        summaryOf(.createDiary, {
          'items': [
            {'title': '周末'},
          ],
        }),
        '周末',
      );
    });

    test('失败输出一律报失败，盖过各自的摘要', () {
      final spec = AssistantToolRegistry.byId(AssistantTool.rememberFact.id)!;
      final input = {
        'items': [
          {'category': 'preference', 'text': '别用感叹号'},
        ],
      };
      expect(
        spec.summaryOf(input, 'Failed: nope'),
        l10n.assistant.toolFailed,
      );
    });

    test('每个写类工具都有摘要，没有一个落进错误的分支', () {
      const writeTools = [
        AssistantTool.createDiary,
        AssistantTool.updateDiary,
        AssistantTool.createCategory,
        AssistantTool.updateCategory,
        AssistantTool.rememberFact,
      ];
      for (final tool in writeTools) {
        final text = summaryOf(tool, jsonDecode('{"items":[{}]}'));
        expect(
          text,
          isNot(l10n.assistant.toolDeleted),
          reason: '${tool.id} 不该报已删除',
        );
      }
    });
  });
}
