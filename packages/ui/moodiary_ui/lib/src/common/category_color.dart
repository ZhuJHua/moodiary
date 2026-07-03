import 'package:flutter/material.dart';

/// 分类色板 —— 无显式配色时按 id 稳定取色。业务无关，供列表卡片 / 分类管理复用。
const List<Color> kCategoryPalette = [
  Color(0xFFEF5350),
  Color(0xFFEC407A),
  Color(0xFFAB47BC),
  Color(0xFF7E57C2),
  Color(0xFF5C6BC0),
  Color(0xFF42A5F5),
  Color(0xFF26A69A),
  Color(0xFF66BB6A),
  Color(0xFFFFA726),
  Color(0xFF8D6E63),
];

Color categoryColorOf({int? colorValue, required String id}) {
  if (colorValue != null) return Color(colorValue);
  final hash = id.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
  return kCategoryPalette[hash % kCategoryPalette.length];
}
