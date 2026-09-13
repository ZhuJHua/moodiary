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
      expect(guardrails, greaterThan(identity));
      expect(persona, greaterThan(guardrails));
      expect(tools, greaterThan(persona));
    });

    test('toolsEnabled=false 时没有工具目录层', () {
      final prompt = buildStableSystemPrompt(persona: 'P', toolsEnabled: false);
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

    test('常驻块排在人格之后、工具目录之前', () {
      final prompt = buildStableSystemPrompt(
        persona: 'PERSONA-MARK',
        toolsEnabled: true,
        profileFacts: const ['FACT-MARK'],
      );
      final persona = prompt.indexOf('PERSONA-MARK');
      final profile = prompt.indexOf('FACT-MARK');
      final tools = prompt.indexOf('Tool guidelines:');
      expect(profile, greaterThan(persona));
      expect(tools, greaterThan(profile));
    });

    test('没有常驻事实时整段消失', () {
      final prompt = buildStableSystemPrompt(persona: 'P', toolsEnabled: true);
      expect(prompt.contains('What you know about this user'), isFalse);
    });

    test('常驻块按条数与总字符封顶', () {
      final prompt = buildStableSystemPrompt(
        persona: 'P',
        toolsEnabled: true,
        profileFacts: [for (var i = 0; i < 20; i++) 'fact-$i'],
      );
      final kept = 'fact-'.allMatches(prompt).length;
      expect(kept, lessThanOrEqualTo(memoryProfileLimit));
    });

    test('单条事实超长会截断', () {
      final long = 'x' * (memoryProfileFactMaxChars + 50);
      final prompt = buildStableSystemPrompt(
        persona: 'P',
        toolsEnabled: true,
        profileFacts: [long],
      );
      expect(prompt.contains(long), isFalse);
      expect(prompt, contains('…'));
    });

    test('检索策略段只在有工具时出现，且不超过 150 词', () {
      final withTools = buildStableSystemPrompt(
        persona: 'P',
        toolsEnabled: true,
      );
      expect(withTools, contains('Memory and retrieval policy'));
      final start = withTools.indexOf('Memory and retrieval policy');
      final end = withTools.indexOf('The following is the user');
      final words = withTools
          .substring(start, end)
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      expect(words, lessThanOrEqualTo(150));

      final without = buildStableSystemPrompt(persona: 'P', toolsEnabled: false);
      expect(without.contains('Memory and retrieval policy'), isFalse);
    });
  });

  group('buildTurnContext', () {
    final at = DateTime(2026, 9, 13, 14, 5);

    test('不再携带任何事实正文，只报数量', () {
      final text = buildTurnContext(
        localeTag: 'zh-CN',
        nowLocal: at,
        factCount: 23,
        semanticSearch: true,
      );
      expect(text.contains('Known facts about the user'), isFalse);
      expect(text, contains('Saved facts: 23'));
      expect(text, contains('semantic diary search: on'));
    });

    test('语义索引关闭时写明只有关键词', () {
      final text = buildTurnContext(
        localeTag: 'zh-CN',
        nowLocal: at,
        factCount: 0,
        semanticSearch: false,
      );
      expect(text, contains('keyword search only'));
    });

    test('记忆够不着时连账本都不出现', () {
      final text = buildTurnContext(localeTag: 'zh-CN', nowLocal: at);
      expect(text.contains('Saved facts'), isFalse);
    });

    test('无工具兜底才注入事实正文', () {
      final text = buildTurnContext(
        localeTag: 'zh-CN',
        nowLocal: at,
        fallbackFacts: const ['(preference) FACT-MARK'],
      );
      expect(text, contains('FACT-MARK'));
      expect(text, contains('no tools in this conversation'));
    });

    test('时间与语言仍在', () {
      final text = buildTurnContext(localeTag: 'en-US', nowLocal: at);
      expect(text, contains('2026-09-13 14:05'));
      expect(text, contains('en-US'));
    });
  });
}
