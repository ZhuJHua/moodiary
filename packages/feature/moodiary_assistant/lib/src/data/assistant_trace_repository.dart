import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_data/moodiary_data.dart';

typedef AssistantTraceTurn = ({
  int turn,
  String finishReason,
  String requestId,
  int inputTokens,
  int outputTokens,
  int cachedInputTokens,
});

@lazySingleton
class AssistantTraceRepository {
  AssistantTraceRepository(this._db);

  final MoodiaryDatabase _db;

  Future<void> put({
    required String messageId,
    required String sessionId,
    required int promptVersion,
    required List<AssistantTraceTurn> turns,
  }) async {
    await _db
        .into(_db.assistantTraces)
        .insertOnConflictUpdate(
          AssistantTracesCompanion.insert(
            messageId: messageId,
            sessionId: sessionId,
            promptVersion: promptVersion,
            turnsJson: jsonEncode([
              for (final t in turns)
                {
                  'turn': t.turn,
                  'finish': t.finishReason,
                  'request_id': t.requestId,
                  'in': t.inputTokens,
                  'out': t.outputTokens,
                  'cached': t.cachedInputTokens,
                },
            ]),
            createdAt: dbTime(DateTime.timestamp()),
          ),
        );
  }

  Future<String> exportSession(String sessionId) async {
    final rows =
        await (_db.select(_db.assistantTraces)
              ..where((t) => t.sessionId.equals(sessionId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return const JsonEncoder.withIndent('  ').convert({
      'session': sessionId,
      'messages': [
        for (final r in rows)
          {
            'message': r.messageId,
            'prompt_version': r.promptVersion,
            'at': dbToTime(r.createdAt).toIso8601String(),
            'turns': jsonDecode(r.turnsJson),
          },
      ],
    });
  }
}
