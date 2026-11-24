import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/assistant_tools.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  group('工具摘要', () {
    AssistantToolSpec specOf(AssistantTool t) =>
        AssistantToolRegistry.byId(t.id)!;

    test('查询：命中数与生效的筛选条件，不截英文结果', () {
      final line = specOf(AssistantTool.searchDiaries).summaryOf({
        'query': '搬家',
        'startDate': '2026-08-11',
        'endDate': '2026-08-17',
      }, '47 matches; the first 8 follow.\nid=x …');
      expect(line, '47 篇 · 搬家 · 2026-08-11 – 2026-08-17');
    });

    test('列举类按 id= 行数数，空列表说无结果', () {
      expect(
        specOf(AssistantTool.listCategories)
            .summaryOf(const {}, 'id=a name=旅行\nid=b name=工作'),
        '2 项',
      );
      expect(
        specOf(AssistantTool.listCategories)
            .summaryOf(const {}, 'No categories yet.'),
        '无结果',
      );
    });

    test('查询无结果', () {
      final line = specOf(AssistantTool.searchDiaries)
          .summaryOf(const {}, 'No diaries yet.');
      expect(line, '无结果');
    });

    test('批量读全文：说篇数', () {
      final line = specOf(AssistantTool.getDiary).summaryOf(const {
        'ids': ['a', 'b', 'c'],
      }, 'id=a …');
      expect(line, '3 篇全文');
    });

    test('批量：只报条数，日记用「篇」、其余用「项」', () {
      expect(
        specOf(AssistantTool.createDiary).summaryOf(const {
          'items': [
            {'title': 'a', 'content': 'x'},
            {'title': 'b', 'content': 'y'},
          ],
        }, 'Created …'),
        '2 篇',
      );
      expect(
        specOf(AssistantTool.rememberFact).summaryOf(const {
          'items': [
            {'text': 'a'},
            {'text': 'b'},
            {'text': 'c'},
          ],
        }, 'Remembered …'),
        '3 项',
      );
    });

    test('批量删除说清楚去了哪，不是「已删除」', () {
      expect(
        specOf(AssistantTool.deleteDiary).summaryOf(const {
          'ids': ['a', 'b', 'c'],
        }, 'Moved …'),
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
        specOf(AssistantTool.deleteDiary)
            .summaryOf(const {'id': 'x'}, 'Moved …'),
        '已移入回收站',
      );
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
          'search_diaries',
          '{"query":"搬家"}',
          '47 matches; the first 8 follow.\n'
              'id=a 【2026-08-11】搬家第一天\n（此处还有两千字）',
        ),
      ]);
      expect(record, startsWith('[tools already run]'));
      expect(record, contains('search_diaries({"query":"搬家"})'));
      expect(record, contains('→ 47 篇 · 搬家'));
      expect(record, isNot(contains('搬家第一天')));
      expect(record, isNot(contains('此处还有两千字')));
    });

    test('没跑完的调用不进记录', () {
      final record = AssistantToolRegistry.recordOf(const [
        AssistantToolCall(callId: 'x', name: 'search_diaries'),
      ]);
      expect(record, isEmpty);
    });

    test('一轮没调工具就是空串', () {
      expect(AssistantToolRegistry.recordOf(const []), isEmpty);
    });

    test('多次调用逐行列出', () {
      final record = AssistantToolRegistry.recordOf([
        call('search_diaries', '{}', '3 matches:'),
        call('get_diary', '{"ids":["a","b"]}', 'id=a …'),
      ]);
      expect(record.split('\n').length, 3);
      expect(record, contains('get_diary({"ids":["a","b"]}) → 2 篇全文'));
    });
  });
}
