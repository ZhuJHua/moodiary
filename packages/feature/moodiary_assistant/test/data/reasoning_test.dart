import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_models/moodiary_models.dart';

LlmModelPreset _model({
  bool reasoning = true,
  List<ReasoningControl>? options,
  int? outputLimit,
}) => LlmModelPreset(
  id: 'm',
  name: 'M',
  protocol: AssistantProviderType.openaiCompletions,
  baseUrl: '',
  reasoning: reasoning,
  reasoningOptions: options,
  outputLimit: outputLimit,
);

void main() {
  group('reasoningLevelsFor', () {
    test('effort 型给出目录里的档位', () {
      final levels = reasoningLevelsFor(
        _model(
          options: const [
            ReasoningControl(
              type: ReasoningControlType.effort,
              values: ['low', 'medium', 'high', 'xhigh'],
            ),
          ],
        ),
      );
      expect(levels, ['low', 'medium', 'high', 'xhigh']);
    });

    test('none 不单独占一档（它就是我们的「关」）', () {
      final levels = reasoningLevelsFor(
        _model(
          options: const [
            ReasoningControl(
              type: ReasoningControlType.effort,
              values: ['none', 'high'],
            ),
          ],
        ),
      );
      expect(levels, ['high']);
    });

    test('只有 budget_tokens 时给固定三档', () {
      final levels = reasoningLevelsFor(
        _model(
          options: const [
            ReasoningControl(type: ReasoningControlType.budgetTokens, min: 1024),
          ],
        ),
      );
      expect(levels, assistantBudgetLevels);
    });

    test('只有 toggle 时不给控件——目录不给字段名，做不出真开关', () {
      final levels = reasoningLevelsFor(
        _model(options: const [ReasoningControl(type: ReasoningControlType.toggle)]),
      );
      expect(levels, isEmpty);
    });

    test('空 options 表示「会思考但无从控制」，同样不给控件', () {
      expect(reasoningLevelsFor(_model(options: const [])), isEmpty);
    });

    test('不推理的模型不给控件', () {
      expect(reasoningLevelsFor(_model(reasoning: false)), isEmpty);
      expect(reasoningLevelsFor(null), isEmpty);
    });
  });

  group('resolveReasoning', () {
    test('空档位 = 关，不注入任何参数', () {
      final r = resolveReasoning(level: '', model: _model(), maxTokens: 8192);
      expect(r.mode, AssistantReasoningMode.off);
    });

    // 新 Claude 只认 effort，老 Claude 只认 budget_tokens；把 budget 发给新模型
    // 是 400，把 effort 发给老模型是无效参数。分派必须照目录来。
    test('effort 型走 effort', () {
      final r = resolveReasoning(
        level: 'high',
        model: _model(
          options: const [
            ReasoningControl(
              type: ReasoningControlType.effort,
              values: ['low', 'high'],
            ),
          ],
        ),
        maxTokens: 8192,
      );
      expect(r.mode, AssistantReasoningMode.effort);
      expect(r.effort, 'high');
    });

    test('只有 budget_tokens 时把档位折算成 token 数并夹进下界', () {
      LlmModelPreset budgetModel() => _model(
        options: const [
          ReasoningControl(type: ReasoningControlType.budgetTokens, min: 1024),
        ],
      );
      final low = resolveReasoning(
        level: 'low',
        model: budgetModel(),
        maxTokens: 8192,
      );
      final high = resolveReasoning(
        level: 'high',
        model: budgetModel(),
        maxTokens: 8192,
      );
      expect(low.mode, AssistantReasoningMode.budget);
      expect(low.budgetTokens, 1024);
      expect(high.budgetTokens, 4096);
      expect(high.budgetTokens, lessThan(8192));
    });

    test('自定义供应商（无目录）按最通用的 effort 下发', () {
      final r = resolveReasoning(level: 'medium', model: null, maxTokens: 8192);
      expect(r.mode, AssistantReasoningMode.effort);
      expect(r.effort, 'medium');
    });
  });

  group('maxTokensFor', () {
    test('以目录的 output limit 为准', () {
      expect(maxTokensFor(32000), 32000);
    });

    test('目录缺失时用兜底值', () {
      expect(maxTokensFor(null), assistantFallbackMaxTokens);
    });

    test('128k 输出的模型被夹到自家上限', () {
      expect(maxTokensFor(128000), assistantMaxTokensCap);
    });
  });
}
