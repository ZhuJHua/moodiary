/// 首页视图模式。[number] 是持久化到 KV 的取值，**永不复用/重排**：list=0 / grid=1 /
/// calendar=2 已随三种旧布局一起删除，它们的号码作废不再分配。
///
/// 切换面板在只有一种模式时自动隐藏模式网格；两种起就会重新出现。
enum ViewModeType {
  timeline(3, 'TimelineView'),
  feed(4, 'FeedView');

  const ViewModeType(this.number, this.value);

  final int number;
  final String value;

  /// 老版本可能在 KV 里留着 0/1/2；这些号码已作废，一律退回当前的默认模式而不是抛异常。
  static ViewModeType getType(int number) => ViewModeType.values.firstWhere(
    (e) => e.number == number,
    orElse: () => ViewModeType.timeline,
  );
}
