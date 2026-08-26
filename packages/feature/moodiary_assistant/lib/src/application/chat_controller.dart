import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';
import 'package:moodiary_assistant/src/data/chat_repository.dart';

/// 聊天列表的内存真源。取代了实现 flutter_chat_core `ChatController` 的
/// `IsarChatController`（连同它那条 `ChatOperation` 广播流）。
///
/// 两条与旧实现不同、且是有意为之的性质：
///
/// 1. **通知是同步的**，所以成批的改动必须包进 [batch] —— 否则「删掉尾部三条」
///    会发三次通知、触发三轮补跳，彼此 abort，列表肉眼可见地抖。
/// 2. **流式增量不走 [notifyListeners]**，改走 [streaming] 这个 [ValueNotifier]。
///    列表只把正在流式的那一条包进 `ValueListenableBuilder`，于是一个 token 只重建
///    一个气泡，而不是让每个可见气泡重跑一遍 Markdown 解析。
class AssistantChatController extends ChangeNotifier {
  /// [repository] 只为测试注入。默认走单例，且是**惰性**取用的 ——
  /// `ChatRepository.get()` 的静态初始化会碰 Isar，宿主单测里一碰就抛。
  AssistantChatController({this.repository});

  /// 注入点，默认 null。
  final ChatRepository? repository;

  ChatRepository get _repo => repository ?? ChatRepository.get();

  final List<AssistantChatItem> _items = [];

  /// 只读视图。是同一个 list 的 view，不是每次取用都新建一份。
  late final List<AssistantChatItem> items = UnmodifiableListView(_items);

  /// 正在流式接收的那一条的实时版本。null 表示当前没有流式。
  final ValueNotifier<AssistantTurn?> streaming = ValueNotifier(null);

  String? sessionId;

  /// **尾部**发生变化的次数。中插 / 中删不计 —— 「跟随底部」只认这个计数，
  /// 否则压缩提示 chip 插在会话中部也会把用户从历史里拽到底部。
  int get tailRevision => _tailRevision;
  int _tailRevision = 0;

  int _muted = 0;
  bool _pending = false;

  @override
  void notifyListeners() {
    if (_muted > 0) {
      _pending = true;
      return;
    }
    super.notifyListeners();
  }

  /// 把一串改动合成一次通知。嵌套安全。
  void batch(void Function() body) {
    _muted++;
    try {
      body();
    } finally {
      _muted--;
      if (_muted == 0 && _pending) {
        _pending = false;
        super.notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    streaming.dispose();
    super.dispose();
  }

  // ── 列表操作 ──────────────────────────────────────────────

  /// 追加到末尾。id 重复时直接忽略（旧实现的同名保护，保留）。
  void add(AssistantChatItem item) {
    if (_items.any((e) => e.id == item.id)) return;
    _items.add(item);
    _tailRevision++;
    notifyListeners();
  }

  /// 插到 [index]。越界即追加（此时算尾部变化）。
  void insertAt(int index, AssistantChatItem item) {
    if (_items.any((e) => e.id == item.id)) return;
    if (index >= _items.length) {
      add(item);
      return;
    }
    _items.insert(index < 0 ? 0 : index, item);
    notifyListeners();
  }

  /// 按 id 就地替换。不在表里就什么都不做。
  void replace(AssistantChatItem item) {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index == -1) return;
    if (identical(_items[index], item)) return;
    _items[index] = item;
    if (index == _items.length - 1) _tailRevision++;
    notifyListeners();
  }

  void remove(AssistantChatItem item) => removeWhere((e) => e.id == item.id);

  void removeWhere(bool Function(AssistantChatItem item) test) {
    final last = _items.isEmpty ? null : _items.last;
    final before = _items.length;
    _items.removeWhere(test);
    if (_items.length == before) return;
    if (last != null && test(last)) _tailRevision++;
    notifyListeners();
  }

  void setAll(Iterable<AssistantChatItem> next) {
    _items
      ..clear()
      ..addAll(next);
    _tailRevision++;
    notifyListeners();
  }

  int indexOfId(String id) => _items.indexWhere((e) => e.id == id);

  // ── 流式 ─────────────────────────────────────────────────

  /// 开一段流式：把占位气泡放进表尾，并挂上实时通道。
  void beginStreaming(AssistantTurn placeholder) {
    add(placeholder);
    streaming.value = placeholder;
  }

  /// 流式增量。**只动 [streaming]，不发列表通知** —— 列表结构没变，
  /// 变的只有那一条气泡的内容。
  void updateStreaming(AssistantTurn next) {
    final index = _items.indexWhere((e) => e.id == next.id);
    if (index != -1) _items[index] = next;
    streaming.value = next;
  }

  /// 收尾：把定稿写回列表并关掉实时通道，发一次通知。
  void endStreaming() {
    streaming.value = null;
    notifyListeners();
  }

  // ── 持久化 ────────────────────────────────────────────────

  Future<void> loadSession(String id) async {
    sessionId = id;
    final stored = await _repo.getMessages(id);
    setAll([for (final m in stored) AssistantTurn.fromRecord(m)]);
  }

  Future<void> persist(AssistantTurn turn) async {
    final sid = sessionId;
    // 会话还没建（首轮 `_ensureSession` 之前）或空气泡：不落库。
    if (sid == null || turn.isEmpty) return;
    await _repo.addMessage(turn.toRecord(sid));
  }

  Future<void> deleteMessage(String id) => _repo.deleteMessage(id);
}
