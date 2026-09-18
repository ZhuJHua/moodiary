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
    String build({
      bool tools = true,
      bool memory = true,
      String notes = '',
      bool confirms = false,
    }) => buildStableSystemPrompt(
      toolsEnabled: tools,
      memoryEnabled: memory,
      userNotes: notes,
      confirmsWrites: confirms,
    );

    test('分层顺序：身份 → 护栏 → 检索策略 → 人格 → 说明 → 工具目录', () {
      final prompt = build(notes: 'NOTES-MARK');
      final marks = [
        'built-in AI assistant of Moodiary',
        'Ground rules',
        'Memory and retrieval policy',
        '# Persona',
        'NOTES-MARK',
        'Tool guidelines:',
      ];
      final offsets = [for (final m in marks) prompt.indexOf(m)];
      expect(offsets.every((o) => o >= 0), isTrue);
      expect(offsets, [...offsets]..sort());
    });

    test('说明为空时整段消失，人格始终内建', () {
      final prompt = build();
      expect(prompt.contains('The user wrote these notes'), isFalse);
      expect(prompt, contains('# Persona'));
    });

    test('记忆关闭时策略段告诉模型去哪开，且不提 recallMemory', () {
      final off = build(memory: false);
      expect(off, contains('turned off in the app settings'));
      expect(off.contains('recallMemory'), isFalse);
      expect(build(memory: true), contains('recallMemory'));
    });

    test('toolsEnabled=false 时没有检索策略和工具目录', () {
      final prompt = build(tools: false);
      expect(prompt.contains('Tool guidelines:'), isFalse);
      expect(prompt.contains('Memory and retrieval policy'), isFalse);
    });

    test('护栏里的工具句跟着权限模式走，其余字节不变', () {
      final free = build();
      final gated = build(confirms: true);
      expect(free, contains('Every tool runs immediately'));
      expect(gated, isNot(contains('Every tool runs immediately')));
      expect(gated, contains(assistantToolSkippedPrefix));
      expect(
        gated.split('Ground rules').first,
        free.split('Ground rules').first,
      );
    });

    test('检索策略段不超过 150 词', () {
      final prompt = build();
      final start = prompt.indexOf('Memory and retrieval policy');
      final end = prompt.indexOf('# Persona');
      final words = prompt
          .substring(start, end)
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      expect(words, lessThanOrEqualTo(150));
    });
  });

  group('buildTurnContext', () {
    final at = DateTime(2026, 9, 13, 14, 5);

    test('只报数量，不带事实正文', () {
      final text = buildTurnContext(
        localeTag: 'zh-CN',
        nowLocal: at,
        factCount: 23,
        semanticSearch: true,
      );
      expect(text, contains('Saved facts: 23'));
      expect(text, contains('semantic diary search: on'));
    });

    test('记忆关闭时连账本都不出现', () {
      final text = buildTurnContext(localeTag: 'zh-CN', nowLocal: at);
      expect(text.contains('Saved facts'), isFalse);
      expect(text, contains('2026-09-13 14:05'));
    });
  });

  test('记忆关闭时下发的工具集不含记忆工具', () {
    final ids = toolIdsWithoutMemory();
    expect(ids, isNot(contains(AssistantTool.recallMemory.id)));
    expect(ids, contains(AssistantTool.searchDiaries.id));
    expect(ids, hasLength(AssistantTool.values.length - memoryTools.length));
  });
}
