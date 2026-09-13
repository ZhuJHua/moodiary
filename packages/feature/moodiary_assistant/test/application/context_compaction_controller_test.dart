import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/application/context_compaction_controller.dart';
import 'package:moodiary_assistant/src/data/assistant.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';

class _FakeAssistant implements AssistantService {
  final String summary;
  int calls = 0;

  _FakeAssistant(this.summary);

  @override
  Stream<AssistantStreamEvent> chat(AssistantChatRequest request) {
    calls++;
    return Stream.value(AssistantStreamEvent.text(summary));
  }
}

void main() {
  final provider = LlmProvider.create(
    name: 'custom',
    type: .openaiCompletions,
    baseUrl: 'https://example.com/v1',
    defaultModel: 'm1',
    sortOrder: 0,
  );
  final session = ChatSession.create(providerId: provider.id, model: 'm1');

  List<CompactionMessage> messages(int n) => [
    for (var i = 0; i < n; i++)
      (id: 'm$i', fromUser: i.isEven, text: 'text $i'),
  ];

  late _FakeAssistant fake;
  late ContextCompactionController controller;

  setUp(() {
    fake = _FakeAssistant('summary');
    getIt.registerSingleton<AssistantService>(fake);
    controller = ContextCompactionController();
  });

  tearDown(getIt.reset);

  Future<ChatSession?> run({
    required int count,
    int inputTokens = 0,
    bool force = false,
    ChatSession? from,
  }) => controller.maybeCompact(
    session: from ?? session,
    orderedMessages: messages(count),
    lastInputTokens: inputTokens,
    contextLimit: 1000,
    provider: provider,
    model: 'm1',
    apiKey: 'k',
    force: force,
  );

  test('自动触发要过条数和 token 比例两道门', () async {
    const few = assistantCompactionMinMessages - 1;
    expect(await run(count: few, inputTokens: 999), isNull);
    expect(
      await run(count: assistantCompactionMinMessages, inputTokens: 100),
      isNull,
    );
    expect(fake.calls, 0);
  });

  test('手动压缩跳过两道门，但尾部之外没东西时仍不动', () async {
    const tail = assistantCompactionTailMessages;
    expect(await run(count: tail, force: true), isNull);
    expect(fake.calls, 0);

    final updated = await run(count: tail + 2, force: true);
    expect(updated?.compactedSummary, 'summary');
    expect(updated?.compactedUpToMessageId, 'm1');
    expect(fake.calls, 1);
  });

  test('hasPending 认水位线：已压到尾部前一条时无事可做', () {
    const tail = assistantCompactionTailMessages;
    final compacted = session.copyWith(compactedUpToMessageId: 'm1');
    expect(
      controller.hasPending(
        session: compacted,
        orderedMessages: messages(tail + 2),
      ),
      isFalse,
    );
    expect(
      controller.hasPending(
        session: compacted,
        orderedMessages: messages(tail + 3),
      ),
      isTrue,
    );
  });
}
