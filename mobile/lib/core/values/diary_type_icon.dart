import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// [DiaryType] 的图标映射（font_awesome）。UI 关注点，置于 app 层；模型包只保留纯枚举。
extension DiaryTypeIcon on DiaryType {
  FaIconData get icon {
    switch (this) {
      case DiaryType.markdown:
        return FontAwesomeIcons.markdown;
      case DiaryType.richText:
        return FontAwesomeIcons.feather;
      case DiaryType.tiptap:
        return FontAwesomeIcons.penNib;
    }
  }
}
