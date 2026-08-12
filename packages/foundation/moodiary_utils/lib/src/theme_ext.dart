import 'package:flutter/material.dart';

/// material 侧的取色/取排版快捷方式。
///
/// **刻意不提供 `theme` getter** —— 那个名字归 mui 的 [MuiThemeData]（见
/// `package:mui`），`context.theme.typography.title1.onSurfaceVariant` 是新代码的
/// 写法。这里剩下的三个是共存期的过渡：material widget 还在读 material 主题，
/// 等它们逐批换成 mui 组件后整个文件删掉。
extension ThemeExt on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == .dark;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  TextTheme get textTheme => Theme.of(this).textTheme;
}
