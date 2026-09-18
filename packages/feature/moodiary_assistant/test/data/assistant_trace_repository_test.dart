import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/assistant_trace_repository.dart';
import 'package:moodiary_assistant/src/data/chat_repository.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late MoodiaryDatabase db;
  late ChatRepository chats;
  late AssistantTraceRepository traces;

  setUp(() {
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    chats = ChatRepository(db);
    traces = AssistantTraceRepository(db);
  });

  tearDown(() => db.close());

  test('随消息落库，删会话时一起消失', () async {
    final session = ChatSession.create(providerId: 'p', model: 'm');
    await chats.upsertSession(session);
    final message = ChatMessage(
      id: 'm1',
      sessionId: session.id,
      role: 'assistant',
      content: 'hi',
      createdAt: DateTime.utc(2026, 9, 18),
    );
    await chats.addMessage(message);
    await traces.put(
      messageId: 'm1',
      sessionId: session.id,
      promptVersion: 2,
      turns: const [
        (
          turn: 1,
          finishReason: 'tool_calls',
          requestId: 'req-1',
          inputTokens: 1200,
          outputTokens: 40,
          cachedInputTokens: 1000,
        ),
        (
          turn: 2,
          finishReason: 'length',
          requestId: 'req-2',
          inputTokens: 1300,
          outputTokens: 800,
          cachedInputTokens: 1200,
        ),
      ],
    );

    final exported = jsonDecode(await traces.exportSession(session.id)) as Map;
    final messages = exported['messages'] as List;
    expect(messages, hasLength(1));
    expect(messages.single['prompt_version'], 2);
    expect((messages.single['turns'] as List).last['finish'], 'length');

    await chats.deleteSession(session.id);
    final after = jsonDecode(await traces.exportSession(session.id)) as Map;
    expect(after['messages'], isEmpty);
  });
}
