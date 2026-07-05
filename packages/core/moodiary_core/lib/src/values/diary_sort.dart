/// 首页日记列表的排序方式（全局偏好，持久化于 `MoodiaryKVs.homeSortMode`）。
/// 只作用于列表 / 瀑布流；日历按日期组织，不受排序影响。
enum DiarySort {
  timeDesc(0),
  timeAsc(1),
  lastModifiedDesc(2);

  const DiarySort(this.number);

  final int number;

  static DiarySort getType(int number) =>
      DiarySort.values.firstWhere((e) => e.number == number);
}
