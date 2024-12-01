import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class TextIndentEmbed extends BlockEmbed {
  const TextIndentEmbed(String value) : super(embedType, value);
  static const String embedType = 'text_indent';
}

class TextIndentEmbedBuilder extends EmbedBuilder {
  final bool isEdit;

  TextIndentEmbedBuilder({required this.isEdit});

  @override
  String get key => TextIndentEmbed.embedType;

  @override
  bool get expanded => false;

  @override
  String toPlainText(Embed node) => '';

  @override
  WidgetSpan buildWidgetSpan(Widget widget) {
    return WidgetSpan(child: widget);
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    var indent = embedContext.node.value.data as String;
    return SizedBox(
      width: (embedContext.textStyle.fontSize ?? 16.0) * int.parse(indent),
      child: isEdit ? Text('\u21E5' * int.parse(indent)) : null,
    );
  }
}
