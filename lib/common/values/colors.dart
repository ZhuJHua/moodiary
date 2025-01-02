import 'package:flutter/material.dart';

import '../../main.dart';

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

  static String colorName(index) {
    return switch (index) {
      0 => l10n.colorNameBaiCaoShuang,
      1 => l10n.colorNameQunQin,
      2 => l10n.colorNameQinDai,
      3 => l10n.colorNameShuiZhuHua,
      4 => l10n.colorNameJiHe,
      5 => l10n.colorNameXiangYe,
      9990 => l10n.specialColorNameMochaMousse,
      _ => l10n.colorNameSystem
    };
  }

  static List<Color> emoColorList = [
    const Color(0xFFFA4659),
    const Color(0xFF2EB872)
  ];
}
