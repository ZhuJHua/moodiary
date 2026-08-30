/// 心情三分类，取值与本地情感模型
/// （distilbert-base-multilingual-cased-sentiments-student）的原始标签一一对应。
/// JSON / 数据库均按 `name` 存字符串。
enum DiaryMood {
  negative,
  neutral,
  positive;

  static DiaryMood fromName(String name) =>
      values.asNameMap()[name] ?? .neutral;
}
