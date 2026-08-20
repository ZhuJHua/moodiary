/// 全局主题与字体：取系统色、解析强调色档位、装载自定义字体，产出 ThemeData。
///
/// 收的是**原始字体描述**（[ActiveFontDescriptor]）而不是 `Font`——那是领域类型，
/// core 不认识它，装配在 moodiary_data 做。
library;

// 只放出 harmonizeWith：上层要把自定义色（分类色等）向主色靠拢，插件与取色部分不外泄。
export 'package:dynamic_color/dynamic_color.dart' show ColorHarmonization;

export 'src/app_color_scheme.dart';
export 'src/font_manager.dart';
export 'src/theme_manager.dart';
