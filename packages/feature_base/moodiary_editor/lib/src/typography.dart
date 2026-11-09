import 'package:flutter/foundation.dart';

/// Font size, line height and paragraph spacing for the editor.
@immutable
class EditorTypography {
  const EditorTypography({
    this.fontSize = 1,
    this.lineHeight = 1.65,
    this.paragraphSpacing = 1,
  });
  final double fontSize, lineHeight, paragraphSpacing;

  @override
  bool operator ==(Object other) =>
      other is EditorTypography &&
      fontSize == other.fontSize &&
      lineHeight == other.lineHeight &&
      paragraphSpacing == other.paragraphSpacing;
  @override
  int get hashCode => Object.hash(fontSize, lineHeight, paragraphSpacing);
}
