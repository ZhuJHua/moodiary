import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  group('AssistantProviderType.fromId', () {
    test('三个值都认得', () {
      for (final t in AssistantProviderType.values) {
        expect(AssistantProviderType.fromId(t.id), t);
      }
    });

    test('认不出来时回落到兼容面最广的 chat completions', () {
      expect(
        AssistantProviderType.fromId(null),
        AssistantProviderType.openaiCompletions,
      );
      expect(
        AssistantProviderType.fromId('gemini'),
        AssistantProviderType.openaiCompletions,
      );
    });

    test('isAnthropic 只对 messages 协议为真', () {
      expect(AssistantProviderType.anthropicMessages.isAnthropic, isTrue);
      expect(AssistantProviderType.openaiCompletions.isAnthropic, isFalse);
      expect(AssistantProviderType.openaiResponses.isAnthropic, isFalse);
    });
  });
}
