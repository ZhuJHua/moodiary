import 'package:flutter/material.dart';

import '../../main.dart';

class AppColor {
  static List<Color> themeColorList = [
    //群青
    const Color(0xFF2E59A7),
    //芰荷
    const Color(0xFF4F794A),
    //青黛
    const Color(0xFF45465E),
    //缃叶
    const Color(0xFFECD452),
    //瑾瑜
    const Color(0xFF1E2732),
  ];

  static String colorName(index) {
    return switch (index) {
      0 => l10n.colorNameQunQin,
      1 => l10n.colorNameJiHe,
      2 => l10n.colorNameQinDai,
      3 => l10n.colorNameXianYe,
      4 => l10n.colorNameJinYu,
      _ => l10n.colorNameSystem
    };
  }

  static List<Color> emoColorList = [
    const Color(0xFFFA4659),
    const Color(0xFF2EB872)
  ];
}
