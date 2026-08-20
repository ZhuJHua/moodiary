import 'dart:async';

import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

class ChatRepository {
  ChatRepository._(this._isar);

  factory ChatRepository.get() => _instance;

  static final ChatRepository _instance = ._(IsarDatabase.get().isar);

  final Isar _isar;

  final StreamController<void> _events = StreamController<void>.broadcast();

  /// 单例随应用整个生命周期存活，不主动关闭。
  Stream<void> get sessionEvents => _events.stream;

  /// 全部会话，按最后活跃时间倒序。
  Future<List<ChatSession>> getAllSessions() {
    return _isar.chatSessions.where().sortByUpdatedAtDesc().findAllAsync();
  }

  Future<ChatSession?> getSession(String id) {
    return _isar.chatSessions.getAsync(id);
  }

  Future<void> upsertSession(ChatSession session) async {
    await _isar.writeAsync((isar) {
      isar.chatSessions.put(session);
    });
    _events.add(null);
  }

  /// 删除会话并连带删除其全部消息。
  Future<void> deleteSession(String id) async {
    await _isar.writeAsync((isar) {
      final ids = isar.chatMessages
          .where()
          .sessionIdEqualTo(id)
          .idProperty()
          .findAll();
      isar.chatMessages.deleteAll(ids);
      isar.chatSessions.delete(id);
    });
    _events.add(null);
  }

  /// 删除单条消息（用于重新生成时清理最后一轮回复）。
  Future<void> deleteMessage(String id) async {
    await _isar.writeAsync((isar) {
      isar.chatMessages.delete(id);
    });
  }

  Future<List<ChatMessage>> getMessages(String sessionId) {
    return _isar.chatMessages
        .where()
        .sessionIdEqualTo(sessionId)
        .sortByCreatedAt()
        .findAllAsync();
  }

  /// 追加一条消息，并把所属会话的 `updatedAt` 顶到该消息时间。
  Future<void> addMessage(ChatMessage message) async {
    await _isar.writeAsync((isar) {
      isar.chatMessages.put(message);
      final session = isar.chatSessions.get(message.sessionId);
      if (session != null) {
        // 活跃时间只向前推进：重新生成会重存较早的用户消息，避免把会话时间倒退。
        final updatedAt = message.createdAt.isAfter(session.updatedAt)
            ? message.createdAt
            : session.updatedAt;
        isar.chatSessions.put(session.copyWith(updatedAt: updatedAt));
      }
    });
    _events.add(null);
  }
}
