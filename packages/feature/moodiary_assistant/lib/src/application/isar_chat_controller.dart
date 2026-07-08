import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_rust/moodiary_rust.dart' show uuidV7;

const String kAssistantUserId = 'user';
const String kAssistantBotId = 'assistant';

const String _kStreamingFlag = 'streaming';

/// assistant 回复的思考 / 推理正文（Markdown）。
const String _kReasoningKey = 'reasoning';

/// 思考耗时（毫秒）。
const String _kThinkingMillisKey = 'thinkingMillis';

/// 是否仍在思考阶段（首个正文 token 到来前为 true，用于展示「思考中…」）。
const String _kThinkingActiveKey = 'thinkingActive';

/// 随消息发送的图片文件名（image 目录内，用 FileUtil.getRealPath 解析）。
const String _kImageNameKey = 'imageName';

const String kPermissionSurfaceKey = 'surfaceId';

class IsarChatController implements ChatController {
  IsarChatController();

  final ChatRepository _repo = ChatRepository.get();
  final StreamController<ChatOperation> _ops =
      StreamController<ChatOperation>.broadcast();
  List<Message> _messages = [];

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

  Future<void> loadSession(String id) async {
    sessionId = id;
    final stored = await _repo.getMessages(id);
    await setMessages([for (final m in stored) _toMessage(m)]);
  }

  void bindNewSession() {
    sessionId = null;
  }

  Future<void> persist(Message message) async {
    final sid = sessionId;
    if (sid == null) return;
    if (message is! TextMessage) return;
    final imageName = imageNameOf(message);
    // 纯图片消息（正文为空但带图）也要落库。
    if (message.text.isEmpty && imageName.isEmpty) return;
    await _repo.addMessage(
      ChatMessage(
        id: message.id,
        sessionId: sid,
        role: message.authorId == kAssistantUserId ? 'user' : 'assistant',
        content: message.text,
        createdAt: message.createdAt ?? DateTime.timestamp(),
        reasoning: reasoningOf(message).isEmpty ? null : reasoningOf(message),
        thinkingMillis: thinkingMillisOf(message) == 0
            ? null
            : thinkingMillisOf(message),
        imageName: imageName.isEmpty ? null : imageName,
      ),
    );
  }

  /// 把思考增量写进流式消息的 metadata（保留 streaming 标记）。[active] 为思考阶段是否进行中。
  TextMessage applyReasoning(
    TextMessage message, {
    required String reasoning,
    required int thinkingMillis,
    required bool active,
  }) {
    return message.copyWith(
      metadata: {
        ...?message.metadata,
        _kReasoningKey: reasoning,
        _kThinkingMillisKey: thinkingMillis,
        _kThinkingActiveKey: active,
      },
    );
  }

  TextMessage userMessage(
    String text, {
    DateTime? createdAt,
    String? imageName,
  }) => TextMessage(
    id: uuidV7(),
    authorId: kAssistantUserId,
    text: text,
    createdAt: createdAt ?? DateTime.timestamp(),
    metadata: (imageName != null && imageName.isNotEmpty)
        ? {_kImageNameKey: imageName}
        : null,
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

  /// 定稿：清掉 streaming / thinkingActive 标记，但保留思考正文与耗时（供落库与回看）。
  TextMessage settled(TextMessage message) {
    final reasoning = reasoningOf(message);
    final millis = thinkingMillisOf(message);
    final meta = <String, dynamic>{
      if (reasoning.isNotEmpty) _kReasoningKey: reasoning,
      if (millis > 0) _kThinkingMillisKey: millis,
    };
    return message.copyWith(metadata: meta);
  }

  CustomMessage permissionCard(String surfaceId) => CustomMessage(
    id: surfaceId,
    authorId: kAssistantBotId,
    createdAt: DateTime.timestamp(),
    metadata: {kPermissionSurfaceKey: surfaceId},
  );

  static bool isStreaming(Message message) =>
      message.metadata?[_kStreamingFlag] == true;

  static bool isThinking(Message message) =>
      message.metadata?[_kThinkingActiveKey] == true;

  static String reasoningOf(Message message) {
    final v = message.metadata?[_kReasoningKey];
    return v is String ? v : '';
  }

  static int thinkingMillisOf(Message message) {
    final v = message.metadata?[_kThinkingMillisKey];
    return v is int ? v : 0;
  }

  static String imageNameOf(Message message) {
    final v = message.metadata?[_kImageNameKey];
    return v is String ? v : '';
  }

  TextMessage _toMessage(ChatMessage m) {
    final reasoning = m.reasoning ?? '';
    final millis = m.thinkingMillis ?? 0;
    final imageName = m.imageName ?? '';
    final meta = <String, dynamic>{
      if (reasoning.isNotEmpty) _kReasoningKey: reasoning,
      if (millis > 0) _kThinkingMillisKey: millis,
      if (imageName.isNotEmpty) _kImageNameKey: imageName,
    };
    return TextMessage(
      id: m.id,
      authorId: m.role == 'user' ? kAssistantUserId : kAssistantBotId,
      text: m.content,
      createdAt: m.createdAt,
      metadata: meta.isEmpty ? null : meta,
    );
  }
}
