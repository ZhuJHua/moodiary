enum DiarySort {
  timeDesc(0),
  timeAsc(1),
  lastModifiedDesc(2);

  const DiarySort(this.number);

  final int number;

  static DiarySort getType(int number) =>
      DiarySort.values.firstWhere((e) => e.number == number);
}
