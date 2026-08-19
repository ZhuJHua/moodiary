import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';

void main() {
  group('assembleSystemPrompt', () {
    test('按 order 升序拼接，与登记顺序无关', () {
      final prompt = assembleSystemPrompt([
        (name: 'b', order: 0, text: 'B'),
        (name: 'c', order: 100, text: 'C'),
        (name: 'a', order: -100, text: 'A'),
      ]);
      expect(prompt, 'A\n\nB\n\nC');
    });

    test('空文本段被丢弃，不留空行', () {
      final prompt = assembleSystemPrompt([
        (name: 'a', order: -1, text: 'A'),
        (name: 'blank', order: 0, text: '   '),
        (name: 'b', order: 1, text: 'B'),
      ]);
      expect(prompt, 'A\n\nB');
    });
  });

  group('buildStableSystemPrompt', () {
    test('分层顺序：身份 → 护栏 → 人格 → 工具目录', () {
      final prompt = buildStableSystemPrompt(
        persona: 'PERSONA-MARK',
        toolsEnabled: true,
      );
      final identity = prompt.indexOf('built-in AI assistant of Moodiary');
      final guardrails = prompt.indexOf('Ground rules');
      final persona = prompt.indexOf('PERSONA-MARK');
      final tools = prompt.indexOf('Tool guidelines:');
      expect(identity, greaterThanOrEqualTo(0));
      // 护栏压在 persona 之前：人格改不掉安全与权限规则。
      expect(guardrails, greaterThan(identity));
      expect(persona, greaterThan(guardrails));
      expect(tools, greaterThan(persona));
    });

    test('toolsEnabled=false 时没有工具目录层', () {
      final prompt = buildStableSystemPrompt(
        persona: 'P',
        toolsEnabled: false,
      );
      expect(prompt.contains('Tool guidelines:'), isFalse);
    });

    test('空 persona 回退内置人格', () {
      final prompt = buildStableSystemPrompt(persona: '  ', toolsEnabled: true);
      expect(prompt, contains(defaultPersona));
    });

    test('同参数逐次调用字节一致（缓存前缀）', () {
      String build() =>
          buildStableSystemPrompt(persona: 'P', toolsEnabled: true);
      expect(build(), build());
    });
  });
}
