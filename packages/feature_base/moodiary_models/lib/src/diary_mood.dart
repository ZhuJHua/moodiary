/// 心情/状态，内建 16 种：前 8 个是情绪、后 8 个是生活状态。
/// 分组只用于选择器面板分区，不进数据模型；JSON / 数据库均按 `name` 存字符串。
enum DiaryMood {
  positive,
  neutral,
  negative,
  excited,
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
