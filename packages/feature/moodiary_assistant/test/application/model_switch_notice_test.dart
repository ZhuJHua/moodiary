import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';

void main() {
  AssistantTurn user(String id) => AssistantTurn(
    id: id,
    fromUser: true,
    text: '问',
    createdAt: DateTime.utc(2026, 8, 19),
  );

  AssistantTurn reply(String id, {String model = ''}) => AssistantTurn(
    id: id,
    fromUser: false,
    text: '答',
    createdAt: DateTime.utc(2026, 8, 19),
    model: model,
  );

  group('modelSwitchNoticesFor', () {
    test('模型没变就没有提示', () {
      final notices = modelSwitchNoticesFor([
        user('u1'),
        reply('a1', model: 'm1'),
        user('u2'),
        reply('a2', model: 'm1'),
      ]);
      expect(notices, isEmpty);
    });

    test('变化点各合成一条，插在切换后首条之前', () {
      final notices = modelSwitchNoticesFor([
        reply('a1', model: 'm1'),
        reply('a2', model: 'm2'),
        reply('a3', model: 'm2'),
        reply('a4', model: 'm1'),
      ]);
      expect(notices.map((n) => (n.beforeId, n.model)), [
        ('a2', 'm2'),
        ('a4', 'm1'),
      ]);
    });

    test('id 由目标消息派生，重复合成幂等', () {
      final items = [reply('a1', model: 'm1'), reply('a2', model: 'm2')];
      final first = modelSwitchNoticesFor(items).single;
      final second = modelSwitchNoticesFor(items).single;
      expect(first.id, second.id);
      expect(first.id, 'model-switch-a2');
    });

    test('旧数据（model 为空）不参与，也不桥接前后两段', () {
      // a2 是升级前的旧行：既不该在它身上出提示，也不该让 m1→m1 被误判成切换。
      final notices = modelSwitchNoticesFor([
        reply('a1', model: 'm1'),
        reply('a2'),
        reply('a3', model: 'm1'),
      ]);
      expect(notices, isEmpty);
    });

    test('user 消息与合成项不打断归属链', () {
      final notices = modelSwitchNoticesFor([
        reply('a1', model: 'm1'),
        const AssistantCompactionNotice('a1'),
        user('u1'),
        reply('a2', model: 'm2'),
      ]);
      expect(notices.single.beforeId, 'a2');
    });

    test('提示永远不指向列表末尾之外（插在消息之前，重试按钮判定不受影响）', () {
      final items = [
        user('u1'),
        reply('a1', model: 'm1'),
        user('u2'),
        reply('a2', model: 'm2'),
      ];
      for (final n in modelSwitchNoticesFor(items)) {
        // beforeId 必是列表里某条消息：提示插在它之前，列表最后一项仍是真消息。
        expect(items.any((m) => m.id == n.beforeId), isTrue);
      }
    });
  });
}
