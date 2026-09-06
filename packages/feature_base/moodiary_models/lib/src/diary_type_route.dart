import 'diary_type.dart';

extension DiaryTypeRouteQuery on DiaryType {
  String get routeQuery => switch (this) {
    .markdown => 'markdown',
    .richText => 'rich-text',
    .tiptap => 'tiptap',
  };
}

DiaryType? diaryTypeFromRouteQuery(String? value) {
  if (value == null) return null;
  for (final type in DiaryType.values) {
    if (type.routeQuery == value) return type;
  }
  return null;
}
