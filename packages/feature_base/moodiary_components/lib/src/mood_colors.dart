import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

/// 心情/状态语义色（业务色，不随主题）。离散取色，两两互异——
/// 时间线渐变连线与「颜色互异」测试都依赖这一点。
abstract class AppColor {
  static const Color moodPositive = Color(0xFF2EB872);
  static const Color moodNeutral = Color(0xFF8A9099);
  static const Color moodNegative = Color(0xFFFA4659);
  static const Color moodFulfilled = Color(0xFFF97316);
  static const Color moodAngry = Color(0xFFDC2626);
  static const Color moodAnxious = Color(0xFF7C3AED);
  static const Color moodTired = Color(0xFF64748B);
  static const Color moodSpeechless = Color(0xFF78716C);
  static const Color moodLove = Color(0xFFEC4899);
  static const Color moodStudy = Color(0xFF3B82F6);
  static const Color moodSlacking = Color(0xFF14B8A6);
  static const Color moodFood = Color(0xFFCA8A04);
  static const Color moodWork = Color(0xFF8D6E63);
  static const Color moodTravel = Color(0xFF0EA5E9);
  static const Color moodSports = Color(0xFF65A30D);
  static const Color moodSick = Color(0xFFBA68C8);
}

extension DiaryMoodVisuals on DiaryMood {
  Color get color => switch (this) {
    .positive => AppColor.moodPositive,
    .neutral => AppColor.moodNeutral,
    .negative => AppColor.moodNegative,
    .fulfilled => AppColor.moodFulfilled,
    .angry => AppColor.moodAngry,
    .anxious => AppColor.moodAnxious,
    .tired => AppColor.moodTired,
    .speechless => AppColor.moodSpeechless,
    .love => AppColor.moodLove,
    .study => AppColor.moodStudy,
    .slacking => AppColor.moodSlacking,
    .food => AppColor.moodFood,
    .work => AppColor.moodWork,
    .travel => AppColor.moodTravel,
    .sports => AppColor.moodSports,
    .sick => AppColor.moodSick,
  };

  IconData get icon => switch (this) {
    .positive => LucideIcons.smile,
    .neutral => LucideIcons.meh,
    .negative => LucideIcons.frown,
    .fulfilled => LucideIcons.sparkles,
    .angry => LucideIcons.angry,
    .anxious => LucideIcons.tornado,
    .tired => LucideIcons.batteryLow,
    .speechless => LucideIcons.annoyed,
    .love => LucideIcons.heart,
    .study => LucideIcons.bookOpen,
    .slacking => LucideIcons.fish,
    .food => LucideIcons.utensils,
    .work => LucideIcons.briefcase,
    .travel => LucideIcons.plane,
    .sports => LucideIcons.dumbbell,
    .sick => LucideIcons.thermometer,
  };

  /// 编辑器 webview 侧按这个名字查 @iconify-json/lucide 组件。
  String get iconName => switch (this) {
    .positive => 'smile',
    .neutral => 'meh',
    .negative => 'frown',
    .fulfilled => 'sparkles',
    .angry => 'angry',
    .anxious => 'tornado',
    .tired => 'battery-low',
    .speechless => 'annoyed',
    .love => 'heart',
    .study => 'book-open',
    .slacking => 'fish',
    .food => 'utensils',
    .work => 'briefcase',
    .travel => 'plane',
    .sports => 'dumbbell',
    .sick => 'thermometer',
  };

  /// widget 里用这个（切语言自动重建）。没有 context 的地方（导出、服务）走 [labelOf]。
  String label(BuildContext context) => labelOf(context.l10n);

  /// 取串不重建的版本：导出的产物落盘即定，不需要跟着语言切换重画。
  String labelOf(Translations l10n) => switch (this) {
    .positive => l10n.common.moodPositive,
    .neutral => l10n.common.moodNeutral,
    .negative => l10n.common.moodNegative,
    .fulfilled => l10n.common.moodFulfilled,
    .angry => l10n.common.moodAngry,
    .anxious => l10n.common.moodAnxious,
    .tired => l10n.common.moodTired,
    .speechless => l10n.common.moodSpeechless,
    .love => l10n.common.moodLove,
    .study => l10n.common.moodStudy,
    .slacking => l10n.common.moodSlacking,
    .food => l10n.common.moodFood,
    .work => l10n.common.moodWork,
    .travel => l10n.common.moodTravel,
    .sports => l10n.common.moodSports,
    .sick => l10n.common.moodSick,
  };
}

/// 手选天气的本地化名称。与 [DiaryMoodVisuals] 同一套写法：widget 里用
/// [label]（切语言自动重建），导出 / 服务这类没有 context 的地方走 [labelOf]。
///
/// 图标不在这里 —— 天气图标是和风字体按 [ManualWeather.code] 取字形
/// （Flutter 侧 `qweatherIcon`，web 侧 qweather-icons 码表），不是 lucide。
extension ManualWeatherLabel on ManualWeather {
  String label(BuildContext context) => labelOf(context.l10n);

  String labelOf(Translations l10n) => switch (this) {
    .sunny => l10n.common.weatherSunny,
    .cloudy => l10n.common.weatherCloudy,
    .overcast => l10n.common.weatherOvercast,
    .showerRain => l10n.common.weatherShowerRain,
    .lightRain => l10n.common.weatherLightRain,
    .moderateRain => l10n.common.weatherModerateRain,
    .heavyRain => l10n.common.weatherHeavyRain,
    .storm => l10n.common.weatherStorm,
    .thundershower => l10n.common.weatherThundershower,
    .lightSnow => l10n.common.weatherLightSnow,
    .heavySnow => l10n.common.weatherHeavySnow,
    .sleet => l10n.common.weatherSleet,
    .foggy => l10n.common.weatherFoggy,
    .haze => l10n.common.weatherHaze,
    .hot => l10n.common.weatherHot,
    .cold => l10n.common.weatherCold,
  };
}
