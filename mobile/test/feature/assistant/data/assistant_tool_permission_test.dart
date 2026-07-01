import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/core/values/assistant.dart';
import 'package:moodiary/feature/assistant/data/assistant_tools.dart';
import 'package:moodiary/feature/assistant/data/impl/rig_assistant.dart';

/// 验证「工具权限闸门」（[dispatchAssistantTool]）在四种情况下分支正确：
/// 未知工具、拒绝、放行、无回调（不校验）。用一个不依赖 Isar 的 dummy 工具规格，
/// 把权限闸门逻辑与 rig / FFI / 仓储解耦后单测。
void main() {
  // run 回显入参，便于验证「放行后确实执行了、且拿到了解析后的入参」。
  final probe = AssistantToolSpec(
    tool: AssistantTool.deleteDiary,
    description: 'probe',
    jsonSchema: const {'type': 'object', 'properties': {}},
    run: (input) async => 'ran:${input['x']}',
  );

  test('unknown tool → returns explanation, does not run', () async {
    final result = await dispatchAssistantTool(
      spec: null,
      toolName: 'nope',
      requester: null,
      argsJson: '{}',
    );
    expect(result, contains('未知工具'));
  });

  test('denied requester → returns denial, does not run', () async {
    final result = await dispatchAssistantTool(
      spec: probe,
      toolName: probe.id,
      requester: (AssistantTool _) async => false,
      argsJson: '{"x":1}',
    );
    expect(result, contains('拒绝'));
    expect(result, isNot(startsWith('ran')));
  });

  test('allowing requester → runs with parsed args', () async {
    final result = await dispatchAssistantTool(
      spec: probe,
      toolName: probe.id,
      requester: (AssistantTool _) async => true,
      argsJson: '{"x":1}',
    );
    expect(result, 'ran:1');
  });

  test('no requester → runs (no gating)', () async {
    final result = await dispatchAssistantTool(
      spec: probe,
      toolName: probe.id,
      requester: null,
      argsJson: '{"x":2}',
    );
    expect(result, 'ran:2');
  });

  test('null / empty args fall back to empty object', () async {
    for (final args in ['null', '', '   ']) {
      final result = await dispatchAssistantTool(
        spec: probe,
        toolName: probe.id,
        requester: null,
        argsJson: args,
      );
      expect(result, 'ran:null');
    }
  });
}
