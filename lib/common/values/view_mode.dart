enum ViewModeType {
  list(0, 'ListView'),
  grid(1, 'GridView');

  const ViewModeType(this.number, this.value);

  final int number;
  final String value;

  static ViewModeType getType(int number) => ViewModeType.values.firstWhere((e) => e.number == number);
}
