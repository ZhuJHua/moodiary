import 'dart:async';

import 'package:injectable/injectable.dart';

/// 进程级单例：记录当前「正在编辑器中打开」的日记 id（业务 uuid）。同步层据此跳过
/// 打开中的日记——编辑期不上传半成品，关闭后由下一轮同步按 LWW 收敛。纯进程内、不
/// 持久化（崩溃 / 重启即清空，靠周期 poll 兜底）。
///
/// 放在 data 是因为 moodiary_sync 与 diary 同为 feature 层、不能互相 import，二者都需
/// 访问它，故下沉到两者都可合法依赖的 data。引用计数支持同一篇多处同开（桌面多窗 /
/// 路由夹层导致的重复实例）：open/close 成对抵扣，减到零才视为关闭。
///
/// [closed] 在计数归零时发出该 id：编辑期被同步层挡下的保存，要靠这个时机补触发
/// 推送——编辑页最后一次自动保存发生在 close 之前，此后再无领域事件。
@singleton
class OpenDiaryRegistry {
  final Map<String, int> _open = <String, int>{};
  final StreamController<String> _closed = StreamController<String>.broadcast();

  Stream<String> get closed => _closed.stream;

  void open(String id) {
    if (id.isEmpty) return;
    _open[id] = (_open[id] ?? 0) + 1;
  }

  void close(String id) {
    final count = _open[id];
    if (count == null) return;
    if (count <= 1) {
      _open.remove(id);
      _closed.add(id);
    } else {
      _open[id] = count - 1;
    }
  }

  bool contains(String id) => _open.containsKey(id);

  /// push 前冻结一份快照，避免「边 push 边有日记开 / 关」导致快照半包含。
  Set<String> snapshot() => Set<String>.unmodifiable(_open.keys);
}
