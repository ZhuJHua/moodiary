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

    test('列举类按 id= 行数数，空列表说无结果', () {
      expect(
        specOf(AssistantTool.listCategories).summaryOf(
          const {},
          'id=a name=旅行\nid=b name=工作',
        ),
        '2 项',
      );
      expect(
        specOf(AssistantTool.listCategories)
            .summaryOf(const {}, 'No categories yet.'),
        '无结果',
      );
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

    test('批量：只报条数，日记用「篇」、其余用「项」', () {
      expect(
        specOf(AssistantTool.createDiary).summaryOf(
          const {
            'items': [
              {'title': 'a', 'content': 'x'},
              {'title': 'b', 'content': 'y'},
            ],
          },
          'Created …',
        ),
        '2 篇',
      );
      expect(
        specOf(AssistantTool.rememberFact).summaryOf(
          const {
            'items': [
              {'text': 'a'},
              {'text': 'b'},
              {'text': 'c'},
            ],
          },
          'Remembered …',
        ),
        '3 项',
      );
    });

    test('批量删除说清楚去了哪，不是「已删除」', () {
      expect(
        specOf(AssistantTool.deleteDiary).summaryOf(
          const {
            'ids': ['a', 'b', 'c'],
          },
          'Moved …',
        ),
        '3 篇已移入回收站',
      );
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

    test('脚本：报算出来的值，不报那段代码', () {
      final spec = specOf(AssistantTool.runJavascript);
      expect(
        spec.summaryOf(const {'code': 'a.reduce((x,y)=>x+y,0)/a.length'}, 'Result: 0.62'),
        '0.62',
      );
      expect(
        spec.summaryOf(const {'code': 'console.log(1)'}, 'Result: (no value)\nConsole:\n[LOG] 1'),
        '无返回值',
      );
    });

    test('失败一律走 Failed 前缀判定，不看语言', () {
      final line = specOf(AssistantTool.deleteDiary)
          .summaryOf(const {}, 'Failed: no diary id given.');
      expect(line, '未成功');
    });
  });

  group('脚本工具的契约', () {
    AssistantToolSpec spec() =>
        AssistantToolRegistry.byId(AssistantTool.runJavascript.id)!;

    test('入参是单个 code，不是 items —— 脚本该把逻辑写在一处', () {
      final schema = spec().jsonSchema;
      expect((schema['properties']! as Map).keys, ['code']);
      expect(schema['required'], ['code']);
    });

    test('空代码不进沙箱', () async {
      final out = await spec().run(const {'code': '   '});
      expect(out, startsWith('Failed:'));
    });

    test('描述里必须写明沙箱够不到日记', () {
      // 模型只能算它自己写进代码里的值；这条不写清楚它会去猜有没有全局的数据。
      final description = spec().description.toLowerCase();
      expect(description, contains('no network'));
      expect(description, contains('no access to the diaries'));
    });
  });

  group('批量执行', () {
    Future<String> Function(Map<String, dynamic>) each(
      Map<String, String> table,
    ) => (item) async {
      final id = item['id'] as String? ?? '';
      final hit = table[id];
      return hit ?? 'Failed: no row with id=$id.';
    };

    test('ids 数组逐条执行，一行一条', () async {
      final out = await AssistantToolRegistry.runBatch(
        const {
          'ids': ['a', 'b'],
        },
        each: each({'a': 'did a.', 'b': 'did b.'}),
      );
      expect(out, 'did a.\ndid b.');
    });

    test('扁平的单条写法照收——模型经常漏掉数组外壳', () async {
      final out = await AssistantToolRegistry.runBatch(
        const {'id': 'a'},
        each: each({'a': 'did a.'}),
      );
      expect(out, 'did a.');
    });

    test('部分失败：成功的那些必须留在结果里，整体不算失败', () async {
      final out = await AssistantToolRegistry.runBatch(
        const {
          'ids': ['a', 'zzz'],
        },
        each: each({'a': 'did a.'}),
      );
      expect(out.startsWith('Failed:'), isFalse);
      expect(out, contains('did a.'));
      expect(out, contains('no row with id=zzz'));
    });

    test('一条都没成才算失败，且前缀只出现一次', () async {
      final out = await AssistantToolRegistry.runBatch(
        const {
          'ids': ['x', 'y'],
        },
        each: each(const {}),
      );
      expect(out.startsWith('Failed:'), isTrue);
      expect('Failed:'.allMatches(out).length, 1);
      expect(out, contains('id=x'));
      expect(out, contains('id=y'));
    });

    test('超出上限的不执行，并且明说还有剩', () async {
      var ran = 0;
      final out = await AssistantToolRegistry.runBatch(
        {
          'ids': [for (var i = 0; i < 5; i++) 'id$i'],
        },
        cap: 2,
        each: (item) async {
          ran++;
          return 'did ${item['id']}.';
        },
      );
      expect(ran, 2);
      expect(out, contains('Only the first 2'));
    });

    test('单项抛错只坏这一项，已经做完的必须留在结果里', () async {
      final ran = <String>[];
      final out = await AssistantToolRegistry.runBatch(
        const {
          'ids': ['a', 'boom', 'c'],
        },
        each: (item) async {
          final id = item['id'] as String;
          if (id == 'boom') throw StateError('kaboom');
          ran.add(id);
          return 'did $id.';
        },
      );
      // 抛出去的话，a 已经落库却会被报成整批失败，模型照提示词重跑 → 写重复数据。
      expect(ran, ['a', 'c']);
      expect(out.startsWith('Failed:'), isFalse);
      expect(out, contains('did a.'));
      expect(out, contains('did c.'));
      expect(out, contains('id=boom'));
      expect(out, contains('kaboom'));
    });

    test('全失败时也要说还有没试过的', () async {
      final out = await AssistantToolRegistry.runBatch(
        {
          'ids': [for (var i = 0; i < 5; i++) 'id$i'],
        },
        cap: 2,
        each: (item) async => 'Failed: no row with id=${item['id']}.',
      );
      expect(out.startsWith('Failed:'), isTrue);
      expect(out, contains('Only the first 2'));
    });

    test('ids 之外的顶层入参并进每一项——「把这几篇都归到某类」', () async {
      final seen = <Map<String, dynamic>>[];
      await AssistantToolRegistry.runBatch(
        const {
          'ids': ['a', 'b'],
          'categoryId': 'travel',
        },
        each: (item) async {
          seen.add(item);
          return 'ok';
        },
      );
      expect(seen, [
        {'id': 'a', 'categoryId': 'travel'},
        {'id': 'b', 'categoryId': 'travel'},
      ]);
    });

    test('items 给成裸对象也认', () async {
      final out = await AssistantToolRegistry.runBatch(
        const {
          'items': {'id': 'a'},
        },
        each: (item) async => 'did ${item['id']}.',
      );
      expect(out, 'did a.');
    });

    test('items 里带内容的形状原样传给每一项', () async {
      final seen = <String>[];
      await AssistantToolRegistry.runBatch(
        const {
          'items': [
            {'id': 'a', 'name': '旅行'},
            {'id': 'b', 'name': '工作'},
          ],
        },
        each: (item) async {
          seen.add('${item['id']}:${item['name']}');
          return 'ok';
        },
      );
      expect(seen, ['a:旅行', 'b:工作']);
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
