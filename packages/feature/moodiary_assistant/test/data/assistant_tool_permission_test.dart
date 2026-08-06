import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_assistant/src/data/impl/rig_assistant.dart';

void main() {
  final probe = AssistantToolSpec(
    tool: .deleteDiary,
    description: 'probe',
    jsonSchema: const {'type': 'object', 'properties': {}},
    run: (input) async => 'ran:${input['x']}',
  );

  final readOnlyProbe = AssistantToolSpec(
    tool: .queryDiaries,
    description: 'probe',
    jsonSchema: const {'type': 'object', 'properties': {}},
    run: (input) async => 'ran:${input['x']}',
  );

  test('read-only tool → runs without asking, ignores denial', () async {
    final result = await dispatchAssistantTool(
      spec: readOnlyProbe,
      toolName: readOnlyProbe.id,
      requester: (AssistantTool _) async => false,
      argsJson: '{"x":9}',
    );
    expect(result, 'ran:9');
  });

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
