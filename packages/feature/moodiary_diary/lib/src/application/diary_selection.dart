import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiarySelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void enter(String id) => state = {id};

  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  void clear() => state = const {};
}

final diarySelectionProvider =
    NotifierProvider<DiarySelectionNotifier, Set<String>>(
      DiarySelectionNotifier.new,
    );
