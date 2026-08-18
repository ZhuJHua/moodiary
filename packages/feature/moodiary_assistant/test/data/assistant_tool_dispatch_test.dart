import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_assistant/src/data/impl/rig_assistant.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 工具分发。**没有事前闸门**——三个删除都可恢复（日记进回收站、分类可重建、
/// 记忆软删），事前确认对可逆操作是过度设计，误删走事后撤销。
void main() {
  final probe = AssistantToolSpec(
    tool: .deleteDiary,
    description: 'probe',
    jsonSchema: const {'type': 'object', 'properties': {}},
    run: (input) async => 'ran:${input['x']}',
  );

  test('未知工具 → 回一句说明，不执行', () async {
    final result = await dispatchAssistantTool(
      spec: null,
      toolName: 'nope',
      argsJson: '{}',
    );
    expect(result, contains('unknown tool'));
  });

  test('破坏性工具也直接执行，不再有确认环节', () async {
    final result = await dispatchAssistantTool(
      spec: probe,
      toolName: probe.id,
      argsJson: '{"x":1}',
    );
    expect(result, 'ran:1');
  });

  test('null / 空参数回退成空对象', () async {
    for (final args in ['', '   ', 'null', '{}']) {
      final result = await dispatchAssistantTool(
        spec: probe,
        toolName: probe.id,
        argsJson: args,
      );
      expect(result, 'ran:null');
    }
  });

  test('执行抛错时以文本回灌，不抛穿 FFI', () async {
    final boom = AssistantToolSpec(
      tool: .deleteDiary,
      description: 'boom',
      jsonSchema: const {'type': 'object', 'properties': {}},
      run: (_) async => throw StateError('nope'),
    );
    final result = await dispatchAssistantTool(
      spec: boom,
      toolName: boom.id,
      argsJson: '{}',
    );
    expect(result, startsWith('Failed:'));
  });

  group('工具摘要', () {
    AssistantToolSpec specOf(AssistantTool t) =>
        AssistantToolRegistry.byId(t.id)!;

    // 给模型的结果是英文，给用户的摘要走 i18n —— 两者刻意解耦。
    test('查询：命中数与生效的筛选条件，不截英文结果', () {
      final line = specOf(AssistantTool.queryDiaries).summaryOf(
        {'keywords': '搬家', 'startDate': '2026-08-11', 'endDate': '2026-08-17'},
        '47 matches; the first 8 follow.\nid=x …',
      );
      expect(line, '47 篇 · 搬家 · 2026-08-11 – 2026-08-17');
    });

    test('查询无结果', () {
      final line = specOf(AssistantTool.queryDiaries)
          .summaryOf(const {}, 'No diaries yet.');
      expect(line, '无结果');
    });

    test('批量读全文：说篇数', () {
      final line = specOf(AssistantTool.getDiary)
          .summaryOf(const {'ids': ['a', 'b', 'c']}, 'id=a …');
      expect(line, '3 篇全文');
    });

    test('写入类说的是动了什么，不是「已创建」', () {
      expect(
        specOf(AssistantTool.createDiary)
            .summaryOf(const {'title': '搬家第一天'}, 'Created "搬家第一天", id=x.'),
        '搬家第一天',
      );
      expect(
        specOf(AssistantTool.deleteDiary).summaryOf(const {'id': 'x'}, 'Moved …'),
        '已移入回收站',
      );
    });

    test('失败一律走 Failed 前缀判定，不看语言', () {
      final line = specOf(AssistantTool.deleteDiary)
          .summaryOf(const {}, 'Failed: no diary id given.');
      expect(line, '未成功');
    });
  });

  group('回灌给模型的工具记录', () {
    AssistantToolCall call(String name, String args, String result) =>
        AssistantToolCall(
          callId: 'c-$name',
          name: name,
          argsJson: args,
          result: result,
          done: true,
        );

    test('带上入参与一行摘要，不重放完整结果', () {
      final record = AssistantToolRegistry.recordOf([
        call(
          'queryDiaries',
          '{"keywords":"搬家"}',
          '47 matches; the first 8 follow.\n'
              'id=a 【2026-08-11】搬家第一天\n（此处还有两千字）',
        ),
      ]);
      expect(record, startsWith('[tools already run]'));
      expect(record, contains('queryDiaries({"keywords":"搬家"})'));
      expect(record, contains('→ 47 篇 · 搬家'));
      // 完整结果不该被重放：跨轮真正丢掉的只是「已经查过了」这件事。
      expect(record, isNot(contains('搬家第一天')));
      expect(record, isNot(contains('此处还有两千字')));
    });

    test('没跑完的调用不进记录', () {
      final record = AssistantToolRegistry.recordOf(const [
        AssistantToolCall(callId: 'x', name: 'queryDiaries'),
      ]);
      expect(record, isEmpty);
    });

    test('一轮没调工具就是空串', () {
      expect(AssistantToolRegistry.recordOf(const []), isEmpty);
    });

    test('多次调用逐行列出', () {
      final record = AssistantToolRegistry.recordOf([
        call('queryDiaries', '{}', '3 matches:'),
        call('getDiary', '{"ids":["a","b"]}', 'id=a …'),
      ]);
      expect(record.split('\n').length, 3);
      expect(record, contains('getDiary({"ids":["a","b"]}) → 2 篇全文'));
    });
  });
}
