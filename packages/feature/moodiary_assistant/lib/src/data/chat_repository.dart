import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

class ChatRepository {
  ChatRepository._(this._db);

  factory ChatRepository.get() => _instance;

  @visibleForTesting
  ChatRepository.forTesting(this._db);

  static final ChatRepository _instance = ._(MoodiaryDatabase.get());

  final MoodiaryDatabase _db;

  /// `WHERE x IN (...)` 的分块上限（SQLite 变量数上限 32766，留足余量）。
  static const int _inChunk = 5000;

  final StreamController<void> _events = StreamController<void>.broadcast();

  /// 单例随应用整个生命周期存活，不主动关闭。
  Stream<void> get sessionEvents => _events.stream;

  // —— 行 ↔ 域模型映射 —— //

  static ChatSession _toSession(ChatSessionRow r) => ChatSession(
    id: r.id,
    title: r.title,
    providerId: r.providerId,
    model: r.model,
    createdAt: dbToTime(r.createdAt),
    updatedAt: dbToTime(r.updatedAt),
    reasoningEffort: r.reasoningEffort,
    compactedSummary: r.compactedSummary,
    compactedUpToMessageId: r.compactedUpToMessageId,
    compactedAt: dbToTimeOrNull(r.compactedAt),
    compactedInputTokensAtTrigger: r.compactedInputTokensAtTrigger,
    agentPresetId: r.agentPresetId,
    personaSnapshot: r.personaSnapshot,
    // null（不限）与 '[]'（一个都不挂）语义不同，不能塌成空列表。
    toolsSnapshot: dbToStringListOrNull(r.toolsSnapshotJson),
  );

  static ChatSessionsCompanion _toSessionCompanion(ChatSession s) =>
      ChatSessionsCompanion.insert(
        id: s.id,
        title: Value(s.title),
        providerId: s.providerId,
        model: s.model,
        createdAt: dbTime(s.createdAt),
        updatedAt: dbTime(s.updatedAt),
        reasoningEffort: Value(s.reasoningEffort),
        compactedSummary: Value(s.compactedSummary),
        compactedUpToMessageId: Value(s.compactedUpToMessageId),
        compactedAt: Value(dbTimeOrNull(s.compactedAt)),
        compactedInputTokensAtTrigger: Value(s.compactedInputTokensAtTrigger),
        agentPresetId: Value(s.agentPresetId),
        personaSnapshot: Value(s.personaSnapshot),
        toolsSnapshotJson: Value(dbStringListOrNull(s.toolsSnapshot)),
      );

  static ChatMessage _toMessage(
    ChatMessageRow r,
    List<AssistantToolCall> toolCalls,
  ) => ChatMessage(
    id: r.id,
    sessionId: r.sessionId,
    role: r.role,
    content: r.content,
    createdAt: dbToTime(r.createdAt),
    reasoning: r.reasoning,
    thinkingMillis: r.thinkingMillis,
    imageName: r.imageName,
    inputTokens: r.inputTokens,
    outputTokens: r.outputTokens,
    model: r.model,
    toolCalls: toolCalls,
  );

  static ChatMessagesCompanion _toMessageCompanion(ChatMessage m) =>
      ChatMessagesCompanion.insert(
        id: m.id,
        sessionId: m.sessionId,
        role: m.role,
        content: m.content,
        createdAt: dbTime(m.createdAt),
        reasoning: Value(m.reasoning),
        thinkingMillis: Value(m.thinkingMillis),
        imageName: Value(m.imageName),
        inputTokens: Value(m.inputTokens),
        outputTokens: Value(m.outputTokens),
        model: Value(m.model),
      );

  static AssistantToolCall _toToolCall(AssistantToolCallRow r) =>
      AssistantToolCall(
        callId: r.callId,
        name: r.name,
        argsJson: r.argsJson,
        result: r.result,
        done: r.done != 0,
      );

  /// 批量装配：一页消息行 → 域模型（子表按 message_id 分块 IN 批量取，无 N+1）。
  Future<List<ChatMessage>> _assemble(List<ChatMessageRow> rows) async {
    if (rows.isEmpty) return const [];
    final callsById = <String, List<AssistantToolCall>>{};
    final ids = [for (final r in rows) r.id];
    for (var start = 0; start < ids.length; start += _inChunk) {
      final chunk = ids.sublist(start, min(start + _inChunk, ids.length));
      final calls =
          await (_db.select(_db.assistantToolCalls)
                ..where((c) => c.messageId.isIn(chunk))
                ..orderBy([(c) => OrderingTerm(expression: c.seq)]))
              .get();
      for (final c in calls) {
        callsById.putIfAbsent(c.messageId, () => []).add(_toToolCall(c));
      }
    }
    return [
      for (final r in rows)
        _toMessage(r, callsById[r.id] ?? const <AssistantToolCall>[]),
    ];
  }

  /// 该消息的 tool_calls 子表整体替换（子表是消息的一部分，随消息一起写）。
  Future<void> _syncToolCalls(ChatMessage message) async {
    await (_db.delete(
      _db.assistantToolCalls,
    )..where((c) => c.messageId.equals(message.id))).go();
    if (message.toolCalls.isEmpty) return;
    await _db.batch((b) {
      b.insertAll(_db.assistantToolCalls, [
        for (var i = 0; i < message.toolCalls.length; i++)
          AssistantToolCallsCompanion.insert(
            messageId: message.id,
            seq: i,
            callId: message.toolCalls[i].callId,
            name: message.toolCalls[i].name,
            argsJson: Value(message.toolCalls[i].argsJson),
            result: Value(message.toolCalls[i].result),
            done: Value(message.toolCalls[i].done ? 1 : 0),
          ),
      ]);
    });
  }

  /// 全部会话，按最后活跃时间倒序。
  Future<List<ChatSession>> getAllSessions() async {
    final rows = await (_db.select(
      _db.chatSessions,
    )..orderBy([(s) => OrderingTerm.desc(s.updatedAt)])).get();
    return [for (final r in rows) _toSession(r)];
  }

  Future<ChatSession?> getSession(String id) async {
    final row = await (_db.select(
      _db.chatSessions,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toSession(row);
  }

  Future<void> upsertSession(ChatSession session) async {
    await _db
        .into(_db.chatSessions)
        .insertOnConflictUpdate(_toSessionCompanion(session));
    _events.add(null);
  }

  /// 删除会话并连带删除其全部消息（消息与工具调用由外键 ON DELETE CASCADE 级联）。
  Future<void> deleteSession(String id) async {
    await (_db.delete(_db.chatSessions)..where((s) => s.id.equals(id))).go();
    _events.add(null);
  }

  /// 删除单条消息（用于重新生成时清理最后一轮回复）。
  Future<void> deleteMessage(String id) async {
    await (_db.delete(_db.chatMessages)..where((m) => m.id.equals(id))).go();
  }

  Future<List<ChatMessage>> getMessages(String sessionId) async {
    final rows =
        await (_db.select(_db.chatMessages)
              ..where((m) => m.sessionId.equals(sessionId))
              ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
            .get();
    return _assemble(rows);
  }

  /// 追加一条消息，并把所属会话的 `updatedAt` 顶到该消息时间。
  Future<void> addMessage(ChatMessage message) async {
    await _db.transaction(() async {
      await _db
          .into(_db.chatMessages)
          .insertOnConflictUpdate(_toMessageCompanion(message));
      await _syncToolCalls(message);
      final session = await (_db.select(
        _db.chatSessions,
      )..where((s) => s.id.equals(message.sessionId))).getSingleOrNull();
      if (session != null) {
        // 活跃时间只向前推进：重新生成会重存较早的用户消息，避免把会话时间倒退。
        final createdAt = dbTime(message.createdAt);
        final updatedAt = createdAt > session.updatedAt
            ? createdAt
            : session.updatedAt;
        await (_db.update(_db.chatSessions)
              ..where((s) => s.id.equals(session.id)))
            .write(ChatSessionsCompanion(updatedAt: Value(updatedAt)));
      }
    });
    _events.add(null);
  }
}
