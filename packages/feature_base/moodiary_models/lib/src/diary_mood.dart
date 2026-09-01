/// 心情状态，内建 16 种，单一平铺概念（2026-08-31 拍板，不再分「情绪/状态」
/// 两组）；JSON / 数据库均按 `name` 存字符串。
enum DiaryMood {
  positive,
  neutral,
  negative,
  fulfilled,
  angry,
  anxious,
  tired,
  speechless,
  love,
  study,
  slacking,
  food,
  work,
  travel,
  sports,
  sick;

  static DiaryMood fromName(String name) =>
      values.asNameMap()[name] ?? .neutral;
}
