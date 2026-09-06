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
