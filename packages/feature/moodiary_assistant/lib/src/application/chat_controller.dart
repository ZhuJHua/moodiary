import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';
import 'package:moodiary_assistant/src/data/chat_repository.dart';
import 'package:moodiary_di/moodiary_di.dart';

class AssistantChatController extends ChangeNotifier {
  AssistantChatController({this.repository});

  final ChatRepository? repository;

  ChatRepository get _repo => repository ?? getIt<ChatRepository>();

  final List<AssistantChatItem> _items = [];

  late final List<AssistantChatItem> items = UnmodifiableListView(_items);

  final ValueNotifier<AssistantTurn?> streaming = ValueNotifier(null);

  String? sessionId;

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

  void add(AssistantChatItem item) {
    if (_items.any((e) => e.id == item.id)) return;
    _items.add(item);
    _tailRevision++;
    notifyListeners();
  }

  void insertAt(int index, AssistantChatItem item) {
    if (_items.any((e) => e.id == item.id)) return;
    if (index >= _items.length) {
      add(item);
      return;
    }
    _items.insert(index < 0 ? 0 : index, item);
    notifyListeners();
  }

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

  void beginStreaming(AssistantTurn placeholder) {
    add(placeholder);
    streaming.value = placeholder;
  }

  void updateStreaming(AssistantTurn next) {
    final index = _items.indexWhere((e) => e.id == next.id);
    if (index != -1) _items[index] = next;
    streaming.value = next;
  }

  void endStreaming() {
    streaming.value = null;
    notifyListeners();
  }

  Future<void> loadSession(String id) async {
    sessionId = id;
    final stored = await _repo.getMessages(id);
    setAll([for (final m in stored) AssistantTurn.fromRecord(m)]);
  }

  Future<void> persist(AssistantTurn turn) async {
    final sid = sessionId;
    if (sid == null || turn.isEmpty) return;
    await _repo.addMessage(turn.toRecord(sid));
  }

  Future<void> deleteMessage(String id) => _repo.deleteMessage(id);
}
