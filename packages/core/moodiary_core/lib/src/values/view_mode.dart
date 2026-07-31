/// 首页视图模式。[number] 是持久化到 KV 的取值，**永不复用/重排**：list=0 / grid=1 /
/// calendar=2 已随三种旧布局一起删除，它们的号码作废不再分配。
///
/// 目前只剩时间线一种；机制保留是为了后续新增布局时直接接上（切换面板在只有一项时
/// 自动隐藏模式网格）。
enum ViewModeType {
  timeline(3, 'TimelineView');

  const ViewModeType(this.number, this.value);

  final int number;
  final String value;

  /// 老版本可能在 KV 里留着 0/1/2；这些号码已作废，一律退回当前的默认模式而不是抛异常。
  static ViewModeType getType(int number) => ViewModeType.values.firstWhere(
    (e) => e.number == number,
    orElse: () => ViewModeType.timeline,
  );
}
