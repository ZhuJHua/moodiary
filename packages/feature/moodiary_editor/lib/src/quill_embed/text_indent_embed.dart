import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Quill BlockEmbed：首行缩进占位。旧版（≤2.7.3）「首行缩进」开启时会在每段行首插入
/// `{"insert":{"text_indent":"2"}}`，其值为缩进的字符数（历史数据恒为 "2"）。新版 tiptap
/// 编辑器改用全局 CSS `text-indent` 实现首行缩进，不再产生此 embed；本 builder 仅用于渲染
/// 旧 richText 日记里遗留的 text_indent —— 渲染成一段等宽留白（宽度 = 字号 × 缩进字符数），
/// 让 flutter_quill 有对应 builder 可用，避免只读旧日记时抛 UnimplementedError。
class TextIndentBlockEmbed extends BlockEmbed {
  const TextIndentBlockEmbed(String value) : super(embedType, value);

  static const String embedType = 'text_indent';
}

class TextIndentEmbedBuilder extends EmbedBuilder {
  TextIndentEmbedBuilder();

  @override
  String get key => TextIndentBlockEmbed.embedType;

  // 行内渲染（等宽留白贴在段首文字前），而非独占一行的块。
  @override
  bool get expanded => false;

  @override
  String toPlainText(Embed node) => '';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final raw = embedContext.node.value.data;
    final indent = raw is String ? (int.tryParse(raw) ?? 2) : 2;
    return SizedBox(width: (embedContext.textStyle.fontSize ?? 16.0) * indent);
  }
}

/// 兜底 builder：任何未注册的历史 embed 类型都降级为零尺寸空白，绝不让 flutter_quill 抛
/// UnimplementedError 而使整篇旧日记正文渲染崩溃。挂到 `QuillEditorConfig.unknownEmbedBuilder`。
class UnknownEmbedBuilder extends EmbedBuilder {
  UnknownEmbedBuilder();

  @override
  String get key => 'unknown';

  @override
  bool get expanded => false;

  @override
  String toPlainText(Embed node) => '';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) =>
      const SizedBox.shrink();
}
