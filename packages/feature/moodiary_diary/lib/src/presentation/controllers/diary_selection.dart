import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diary_selection.g.dart';

@Riverpod(keepAlive: true)
class DiarySelection extends _$DiarySelection {
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
