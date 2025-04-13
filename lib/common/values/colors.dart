import 'package:flutter/material.dart';
import 'package:moodiary/l10n/l10n.dart';

enum AppColorType {
  common(0),
  pantone(1);

  final int value;

  const AppColorType(this.value);
}

class AppColor {
  static List<Color> themeColorList = [
    //百草霜
    const Color(0xFF303030),
    //群青
    const Color(0xFF2E59A7),
    //青黛
    const Color(0xFF45465E),
    //水朱华
    const Color(0xFFA72126),
    //芰荷
    const Color(0xFF4F794A),
    //缃叶
    const Color(0xFFECD452),
  ];

  static List<Color> specialColorList = [
    // PANTONE 2025 Mocha Mousse
    const Color(0xFFA47B67),
  ];

  // PANTONE 2008 Blue Iris
  static Color answerColor = const Color(0xFF5A5B9F);

  static String colorName(index, BuildContext context) {
    return switch (index) {
      0 => context.l10n.colorNameBaiCaoShuang,
      1 => context.l10n.colorNameQunQin,
      2 => context.l10n.colorNameQinDai,
      3 => context.l10n.colorNameShuiZhuHua,
      4 => context.l10n.colorNameJiHe,
      5 => context.l10n.colorNameXiangYe,
      9990 => context.l10n.specialColorNameMochaMousse,
      _ => context.l10n.colorNameSystem,
    };
  }

  static List<Color> emoColorList = [
    const Color(0xFFFA4659),
    const Color(0xFF2EB872),
  ];
}

class ShareCardColor {
  static List<Color> cardColorList = [
    const Color(0xFFF8F3D4),
    const Color(0xFFF5F5F5),
    const Color(0xFFFFFFFF),
    const Color(0xFF393e46),
    const Color(0xFF252A34),
    const Color(0xFF212121),
    const Color(0xFF000000),
  ];
}
