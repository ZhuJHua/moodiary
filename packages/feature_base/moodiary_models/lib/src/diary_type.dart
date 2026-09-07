enum DiaryType {
  markdown('markdown'),

  richText('richText'),

  tiptap('tiptap');

  final String value;

  const DiaryType(this.value);

  static DiaryType fromValue(String value) {
    return DiaryType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DiaryType.richText,
    );
  }

  bool get isEditable => this == .tiptap;
}
