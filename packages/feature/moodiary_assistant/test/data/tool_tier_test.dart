import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';

void main() {
  group('工具档位按可逆性', () {
    test('updateDiary 只有带 content 才是不可逆', () {
      expect(
        assistantToolTier(.updateDiary, {
          'items': [
            {'id': 'd', 'title': 'x'},
          ],
        }),
        AssistantToolTier.write,
      );
      expect(
        assistantToolTier(.updateDiary, {
          'items': [
            {'id': 'd', 'content': '重写'},
          ],
        }),
        AssistantToolTier.destructive,
      );
    });

    test('删日记进回收站算可逆，删分类和删记忆不可逆', () {
      expect(
        assistantToolTier(.deleteDiary, const {}),
        AssistantToolTier.write,
      );
      expect(
        assistantToolTier(.deleteCategory, const {}),
        AssistantToolTier.destructive,
      );
      expect(
        assistantToolTier(.forgetFact, const {}),
        AssistantToolTier.destructive,
      );
      expect(
        assistantToolTier(.searchDiaries, const {}),
        AssistantToolTier.read,
      );
    });
  });

  group('三种模式', () {
    test('变更前确认：读直跑，其余都问', () {
      expect(assistantToolNeedsConfirmation(.confirm, .read), isFalse);
      expect(assistantToolNeedsConfirmation(.confirm, .write), isTrue);
      expect(assistantToolNeedsConfirmation(.confirm, .destructive), isTrue);
    });

    test('自动编辑：只问不可逆', () {
      expect(assistantToolNeedsConfirmation(.auto, .write), isFalse);
      expect(assistantToolNeedsConfirmation(.auto, .destructive), isTrue);
    });

    test('完全访问：什么都不问，护栏文案也不提确认', () {
      expect(assistantToolNeedsConfirmation(.full, .destructive), isFalse);
      expect(AssistantPermissionMode.full.confirmsWrites, isFalse);
      expect(
        AssistantPermissionMode.fromId('bogus'),
        AssistantPermissionMode.confirm,
      );
    });
  });

  test('改名映射的目标都是活着的工具，来源都已退役', () {
    final live = {for (final t in AssistantTool.values) t.id};
    for (final e in renamedAssistantToolIds.entries) {
      expect(live, contains(e.value));
      expect(live, isNot(contains(e.key)));
    }
  });

  test('错误码从桥上的异常文本里取', () {
    expect(
      assistantErrorCode('AnyhowException(max_turns: reached)'),
      'max_turns',
    );
    expect(assistantErrorCode('unknown_tool: model called x'), 'unknown_tool');
    expect(assistantErrorCode('something else'), isNull);
  });
}
