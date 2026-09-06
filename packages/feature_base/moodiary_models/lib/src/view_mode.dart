enum ViewModeType {
  timeline(3, 'TimelineView'),
  feed(4, 'FeedView');

  const ViewModeType(this.number, this.value);

  final int number;
  final String value;

  static ViewModeType getType(int number) => ViewModeType.values.firstWhere(
    (e) => e.number == number,
    orElse: () => ViewModeType.timeline,
  );
}
