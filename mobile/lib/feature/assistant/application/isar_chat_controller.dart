import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_rust/moodiary_rust.dart' show uuidV7;

/// 聊天双方固定的 authorId。flutter_chat_ui 以 `authorId == currentUserId` 判定「我方」。
const String kAssistantUserId = 'user';
const String kAssistantBotId = 'assistant';

/// 流式输出中的助手占位泡的 metadata 标记（用于隐藏复制按钮）。
const String _kStreamingFlag = 'streaming';

/// 权限卡片（[CustomMessage]）在 metadata 里携带的 surface id 键。
const String kPermissionSurfaceKey = 'surfaceId';

/// 基于 Isar 的 [ChatController]：把 flutter_chat_ui 的消息读写接到 [ChatRepository]。
///
/// - 内存维护当前会话的消息列表 + 操作流，驱动 UI；流式增量经 [updateMessage] 就地更新单条
///   消息（不动列表结构），因此列表位置在 AI 生成时保持稳定。
/// - 完整文本消息按 id 幂等地固化到 Isar（[persist]）；流式 token 只走内存，避免逐字写库。
/// - 权限卡片等非文本项（[CustomMessage]）不落库。
class IsarChatController implements ChatController {
  IsarChatController();

  final ChatRepository _repo = ChatRepository.get();
  final StreamController<ChatOperation> _ops =
      StreamController<ChatOperation>.broadcast();
  List<Message> _messages = [];

  /// 当前绑定的会话 id；null 表示尚未落库的新会话。
  String? sessionId;

  @override
  List<Message> get messages => _messages;

  @override
  Stream<ChatOperation> get operationsStream => _ops.stream;

  @override
  Future<void> insertMessage(Message message, {int? index}) async {
    if (_ops.isClosed) return;
    if (_messages.any((m) => m.id == message.id)) return;
    if (index == null || index >= _messages.length) {
      _messages.add(message);
      _ops.add(ChatOperation.insert(message, _messages.length - 1));
    } else {
      final i = index < 0 ? 0 : index;
      _messages.insert(i, message);
      _ops.add(ChatOperation.insert(message, i));
    }
  }

  @override
  Future<void> insertAllMessages(List<Message> messages, {int? index}) async {
    if (_ops.isClosed) return;
    if (messages.isEmpty) return;
    if (index == null || index >= _messages.length) {
      final start = _messages.length;
      _messages.addAll(messages);
      _ops.add(ChatOperation.insertAll(messages, start));
    } else {
      final i = index < 0 ? 0 : index;
      _messages.insertAll(i, messages);
      _ops.add(ChatOperation.insertAll(messages, i));
    }
  }

  @override
  Future<void> updateMessage(Message oldMessage, Message newMessage) async {
    if (_ops.isClosed) return;
    final i = _messages.indexWhere((m) => m.id == oldMessage.id);
    if (i == -1) return;
    final actualOld = _messages[i];
    if (actualOld == newMessage) return;
    _messages[i] = newMessage;
    _ops.add(ChatOperation.update(actualOld, newMessage, i));
  }

  @override
  Future<void> removeMessage(Message message) async {
    if (_ops.isClosed) return;
    final i = _messages.indexWhere((m) => m.id == message.id);
    if (i == -1) return;
    final removed = _messages[i];
    _messages.removeAt(i);
    _ops.add(ChatOperation.remove(removed, i));
  }

  @override
  Future<void> setMessages(List<Message> messages) async {
    if (_ops.isClosed) return;
    _messages = List.of(messages);
    _ops.add(ChatOperation.set(_messages, animated: _messages.isNotEmpty));
  }

  @override
  void dispose() {
    _ops.close();
  }

  // ---- Isar 接入 ----

  /// 载入某会话的历史消息（替换当前列表，并绑定该会话）。
  Future<void> loadSession(String id) async {
    sessionId = id;
    final stored = await _repo.getMessages(id);
    await setMessages([for (final m in stored) _toMessage(m)]);
  }

  /// 切到尚未落库的「新会话」。调用方随后用 [setMessages] 放入欢迎语。
  void bindNewSession() {
    sessionId = null;
  }

  /// 把一条文本消息固化到 Isar（按消息 id 幂等 upsert）。
  /// 非文本 / 空文本 / 未绑定会话时跳过。
  Future<void> persist(Message message) async {
    final sid = sessionId;
    if (sid == null) return;
    if (message is! TextMessage || message.text.isEmpty) return;
    await _repo.addMessage(
      ChatMessage(
        id: message.id,
        sessionId: sid,
        role: message.authorId == kAssistantUserId ? 'user' : 'assistant',
        content: message.text,
        createdAt: message.createdAt ?? DateTime.timestamp(),
      ),
    );
  }

  // ---- 消息工厂（集中 authorId / 标记，避免漂移）----

  TextMessage userMessage(String text, {DateTime? createdAt}) => TextMessage(
    id: uuidV7(),
    authorId: kAssistantUserId,
    text: text,
    createdAt: createdAt ?? DateTime.timestamp(),
  );

  TextMessage assistantMessage(
    String text, {
    bool streaming = false,
    DateTime? createdAt,
  }) => TextMessage(
    id: uuidV7(),
    authorId: kAssistantBotId,
    text: text,
    createdAt: createdAt ?? DateTime.timestamp(),
    metadata: streaming ? const {_kStreamingFlag: true} : null,
  );

  /// 把占位泡标记为「已完成」（清掉流式标记），返回新消息（仍同一 id）。
  TextMessage settled(TextMessage message) =>
      message.copyWith(metadata: const <String, dynamic>{});

  CustomMessage permissionCard(String surfaceId) => CustomMessage(
    id: surfaceId,
    authorId: kAssistantBotId,
    createdAt: DateTime.timestamp(),
    metadata: {kPermissionSurfaceKey: surfaceId},
  );

  static bool isStreaming(Message message) =>
      message.metadata?[_kStreamingFlag] == true;

  TextMessage _toMessage(ChatMessage m) => TextMessage(
    id: m.id,
    authorId: m.role == 'user' ? kAssistantUserId : kAssistantBotId,
    text: m.content,
    createdAt: m.createdAt,
  );
}
