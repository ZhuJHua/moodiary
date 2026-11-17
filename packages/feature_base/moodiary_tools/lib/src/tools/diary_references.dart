import 'package:flutter/foundation.dart' show internal;

import 'tool_def.dart';

@internal
List<DiaryRef> diaryReferences(String name, Map<String, Object?> data) {
  if (name.contains('categor') || name == 'get_stats' || name == 'list_tags') {
    return const [];
  }
  final ids = <String>{};
  void add(Object? value) {
    if (value is Map && value['id'] is String) ids.add(value['id'] as String);
  }

  add(data);
  add(data['diary']);
  for (final key in ['diaries', 'hits']) {
    if (data[key] case final List rows) {
      for (final row in rows) {
        add(row);
      }
    }
  }
  return [for (final id in ids) DiaryRef(id)];
}
