import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 首页日记「长按多选」的选中集合（业务 id）。空集 = 未进入多选态。
/// 长按进入并选中第一篇；点击切换；取消/删空即退出。app 侧首页壳与包内列表体共享此状态。
class DiarySelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// 长按进入多选并选中该篇。
  void enter(String id) => state = {id};

  /// 点击切换选中；删空则退出多选。
  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  /// 退出多选。
  void clear() => state = const {};
}

final diarySelectionProvider =
    NotifierProvider<DiarySelectionNotifier, Set<String>>(
      DiarySelectionNotifier.new,
    );
