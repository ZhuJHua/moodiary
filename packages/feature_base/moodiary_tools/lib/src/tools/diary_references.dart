List<String> diaryIdsIn(Map data) {
  final ids = <String>{};
  void add(Object? value) {
    if (value is Map && value['id'] is String) ids.add(value['id'] as String);
  }

  add(data);
  add(data['diary']);
  for (final key in ['diaries', 'hits', 'forward', 'backlinks']) {
    if (data[key] case final List rows) {
      for (final row in rows) {
        add(row);
      }
    }
  }
  if (data['results'] case final List results) {
    for (final row in results) {
      if (row is Map && row['ok'] == true) {
        add(row);
        add(row['diary']);
      }
    }
  }
  return ids.toList();
}
