import 'package:flutter/material.dart';

class AppColor {
  /// 心情色带的两端（低 → 高）。灰度 UI 下这是屏幕上少数几处有彩色之一 ——
  /// 心情是全 App 语义最强的可视化维度，不跟着主题走。
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
