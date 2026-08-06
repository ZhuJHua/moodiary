import 'diary_type.dart';

/// [DiaryType] 的路由查询串编码，刻意区别于 [DiaryType.value]：为保持既有 URL 编码
/// （`richText` → `rich-text`，而非 `richText`），路由层用此映射。纯字符串、零依赖，
/// 故 foundation 的 `moodiary_router` 只收发字符串、不引入领域枚举，编解码留在领域层。
extension DiaryTypeRouteQuery on DiaryType {
  String get routeQuery => switch (this) {
    .markdown => 'markdown',
    .richText => 'rich-text',
    .tiptap => 'tiptap',
  };
}

/// 反解路由查询串；未知或空值返回 null（调用方通常兜底 [DiaryType.tiptap]）。
DiaryType? diaryTypeFromRouteQuery(String? value) {
  if (value == null) return null;
  for (final type in DiaryType.values) {
    if (type.routeQuery == value) return type;
  }
  return null;
}
