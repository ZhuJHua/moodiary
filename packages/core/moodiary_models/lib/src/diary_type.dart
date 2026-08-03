/// 日记内容格式。作为 [Diary.type] 的字段类型，属领域模型层，不带任何表现层信息 ——
/// 要给类型配图标 / 文案，放到用它的那一层去。
enum DiaryType {
  /// 旧的 markdown 文本编辑器（现仅作兼容只读；编辑需经迁移工具转 [tiptap]）。
  markdown('markdown'),

  /// 旧的 flutter_quill 富文本（Delta JSON；现仅作兼容只读；编辑需迁移转 [tiptap]）。
  richText('richText'),

  /// 当前唯一可创建 / 可编辑的类型：TipTap 编辑器，content 存文档 JSON、contentText 存纯文本。
  tiptap('tiptap');

  final String value;

  const DiaryType(this.value);

  /// orElse 兜底旧 `text` 类型（2.8.0 迁移到 [richText]）的零星残留，保证仍可读取。
  static DiaryType fromValue(String value) {
    return DiaryType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DiaryType.richText,
    );
  }

  /// 旧格式（markdown / richText）只读，需经迁移工具转成 [tiptap] 才能编辑。
  bool get isEditable => this == DiaryType.tiptap;
}
