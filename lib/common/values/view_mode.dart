enum ViewModeType {
  list(0, 'ListView'),
  calendar(1, 'CalendarView');

  const ViewModeType(this.number, this.value);

  final int number;
  final String value;

  static ViewModeType getType(int number) => ViewModeType.values.firstWhere((e) => e.number == number);
}
