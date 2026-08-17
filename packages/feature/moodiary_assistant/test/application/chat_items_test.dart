import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/application/chat_controller.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  // 磁盘上区分两种角色的只有 'user' / 'assistant' 两个字面量。换成枚举的 .name
  // 或改大小写，历史会全部读回成 assistant：整段对话左对齐，而「重新回答」
  // 找不到最后一条用户消息、静默什么都不做。
  group('ChatMessage 往返', () {
    ChatMessage record({
      String role = kRoleAssistant,
      String? reasoning,
      int? thinkingMillis,
      String? imageName,
      int? inputTokens,
      int? outputTokens,
    }) => ChatMessage(
      id: 'm1',
      sessionId: 's1',
      role: role,
      content: '正文',
      createdAt: DateTime.utc(2026, 8, 17, 10),
      reasoning: reasoning,
      thinkingMillis: thinkingMillis,
      imageName: imageName,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
    );

    test('五个可空列全带值时逐字段恒等', () {
      final original = record(
        role: kRoleUser,
        reasoning: '想了想',
        thinkingMillis: 1200,
        imageName: 'a.jpg',
        inputTokens: 30,
        outputTokens: 40,
      );
      final back = AssistantTurn.fromRecord(original).toRecord('s1');
      expect(back, original);
    });

    test('五个可空列全为空时也恒等（空串 / 0 要写回 null）', () {
      final original = record();
      final back = AssistantTurn.fromRecord(original).toRecord('s1');
      expect(back, original);
      expect(back.reasoning, isNull);
      expect(back.thinkingMillis, isNull);
      expect(back.imageName, isNull);
      expect(back.inputTokens, isNull);
      expect(back.outputTokens, isNull);
    });

    test('role 的两个字面量钉死', () {
      expect(kRoleUser, 'user');
      expect(kRoleAssistant, 'assistant');
      expect(AssistantTurn.fromRecord(record(role: 'user')).fromUser, isTrue);
      expect(
        AssistantTurn.fromRecord(record(role: 'assistant')).fromUser,
        isFalse,
      );
      expect(AssistantTurn.user('x').toRecord('s').role, 'user');
      expect(AssistantTurn.assistant('x').toRecord('s').role, 'assistant');
    });

    // 旧的 settled() 是重建整张 metadata，顺手把 imageName 丢了。
    test('settled 只清两个瞬态标记，不碰 imageName 与用量', () {
      final turn = AssistantTurn(
        id: 'm1',
        fromUser: true,
        text: '正文',
        createdAt: DateTime.utc(2026, 8, 17),
        imageName: 'a.jpg',
        reasoning: '想了想',
        thinkingMillis: 900,
        inputTokens: 12,
        outputTokens: 34,
        streaming: true,
        thinkingActive: true,
      ).settled;

      expect(turn.streaming, isFalse);
      expect(turn.thinkingActive, isFalse);
      expect(turn.imageName, 'a.jpg');
      expect(turn.reasoning, '想了想');
      expect(turn.thinkingMillis, 900);
      expect(turn.inputTokens, 12);
      expect(turn.outputTokens, 34);
    });
  });

  test('压缩提示卡的 id 由水位派生，重复合成幂等', () {
    expect(const AssistantCompactionNotice('w1').id, 'compaction-w1');
    expect(
      const AssistantCompactionNotice('w1').id,
      const AssistantCompactionNotice('w1').id,
    );
  });

  group('AssistantChatController', () {
    late AssistantChatController controller;

    AssistantTurn turn(String id) => AssistantTurn(
      id: id,
      fromUser: true,
      text: id,
      createdAt: DateTime.utc(2026, 8, 17),
    );

    setUp(() {
      // 不传 repository：仓库是惰性取用的，只要不碰持久化就不会去碰 Isar。
      controller = AssistantChatController();
    });

    tearDown(() => controller.dispose());

    test('按 id 去重，重复 add 不进表', () {
      controller
        ..add(turn('a'))
        ..add(turn('a'));
      expect(controller.items.length, 1);
    });

    test('insertAt 越界即追加，并算作尾部变化', () {
      controller.add(turn('a'));
      final before = controller.tailRevision;
      controller.insertAt(99, turn('b'));
      expect(controller.items.map((e) => e.id), ['a', 'b']);
      expect(controller.tailRevision, greaterThan(before));
    });

    // 跟随底部只认尾部变化：压缩 chip 插在会话中部不该把用户从历史里拽走。
    test('中插不算尾部变化', () {
      controller
        ..add(turn('a'))
        ..add(turn('b'));
      final before = controller.tailRevision;
      controller.insertAt(1, const AssistantCompactionNotice('a'));
      expect(controller.items.map((e) => e.id), ['a', 'compaction-a', 'b']);
      expect(controller.tailRevision, before);
    });

    test('replace 按 id 就地替换，末位替换算尾部变化', () {
      controller
        ..add(turn('a'))
        ..add(turn('b'));
      final before = controller.tailRevision;
      controller.replace(turn('b').copyWith(text: '改了'));
      expect((controller.items.last as AssistantTurn).text, '改了');
      expect(controller.tailRevision, greaterThan(before));
    });

    test('replace 不在表里的 id 什么都不做', () {
      controller.add(turn('a'));
      controller.replace(turn('zzz'));
      expect(controller.items.length, 1);
    });

    test('batch 把多次改动合成一次通知', () {
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.batch(() {
        controller
          ..add(turn('a'))
          ..add(turn('b'))
          ..add(turn('c'));
      });
      expect(controller.items.length, 3);
      expect(notifications, 1);
    });

    test('batch 里没有改动就不发通知', () {
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.batch(() {});
      expect(notifications, 0);
    });

    // 流式增量只动 streaming 通道，列表结构没变就不该让整列表重建。
    test('updateStreaming 不发列表通知，但写回了表里那一条', () {
      controller.beginStreaming(
        AssistantTurn.assistant('', streaming: true).copyWith(),
      );
      final placeholder = controller.items.last as AssistantTurn;

      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.updateStreaming(placeholder.copyWith(text: '你'));
      controller.updateStreaming(placeholder.copyWith(text: '你好'));

      expect(notifications, 0);
      expect(controller.streaming.value?.text, '你好');
      expect((controller.items.last as AssistantTurn).text, '你好');
    });

    test('endStreaming 关掉通道并发一次通知', () {
      controller.beginStreaming(AssistantTurn.assistant('', streaming: true));
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.endStreaming();
      expect(controller.streaming.value, isNull);
      expect(notifications, 1);
    });

    test('removeWhere 删掉末位算尾部变化', () {
      controller
        ..add(turn('a'))
        ..add(turn('b'));
      final before = controller.tailRevision;
      controller.removeWhere((e) => e.id == 'b');
      expect(controller.items.map((e) => e.id), ['a']);
      expect(controller.tailRevision, greaterThan(before));
    });

    test('removeWhere 一个都没删就不发通知', () {
      controller.add(turn('a'));
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.removeWhere((e) => e.id == 'nope');
      expect(notifications, 0);
    });
  });
}
