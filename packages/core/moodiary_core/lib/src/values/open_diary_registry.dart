/// 进程级单例：记录当前「正在编辑器中打开」的日记 id（业务 uuid）。同步层据此跳过
/// 打开中的日记——编辑期不上传半成品，关闭后由下一轮同步按 LWW 收敛。纯进程内、不
/// 持久化（崩溃 / 重启即清空，靠周期 poll 兜底）。
///
/// 放在 core 是因为 moodiary_sync 与 diary 同为 feature 层、不能互相 import，二者都需
/// 访问它，故下沉到两者都可合法依赖的 core。用 [Set] 支持桌面 / 链接跳转时多篇同开。
class OpenDiaryRegistry {
  OpenDiaryRegistry._();

  static final OpenDiaryRegistry instance = OpenDiaryRegistry._();

  final Set<String> _open = <String>{};

  void open(String id) {
    if (id.isEmpty) return;
    _open.add(id);
  }

  void close(String id) {
    _open.remove(id);
  }

  bool contains(String id) => _open.contains(id);

  /// push 前冻结一份快照，避免「边 push 边有日记开 / 关」导致快照半包含。
  Set<String> snapshot() => Set<String>.unmodifiable(_open);
}
