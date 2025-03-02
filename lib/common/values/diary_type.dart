import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum DiaryType {
  text('text'),
  markdown('markdown'),
  richText('richText');

  final String value;

  const DiaryType(this.value);

  static DiaryType fromValue(String value) {
    return DiaryType.values.firstWhere((e) => e.value == value);
  }
}

extension DiaryTypeIcon on DiaryType {
  IconData get icon {
    switch (this) {
      case DiaryType.text:
        return FontAwesomeIcons.font;
      case DiaryType.markdown:
        return FontAwesomeIcons.markdown;
      case DiaryType.richText:
        return FontAwesomeIcons.feather;
    }
  }
}
