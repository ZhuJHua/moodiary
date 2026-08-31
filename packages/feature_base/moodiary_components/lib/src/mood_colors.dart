import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

/// 心情/状态语义色（业务色，不随主题）。离散取色，两两互异——
/// 时间线渐变连线与「颜色互异」测试都依赖这一点。
abstract class AppColor {
  static const Color moodPositive = Color(0xFF2EB872);
  static const Color moodNeutral = Color(0xFF8A9099);
  static const Color moodNegative = Color(0xFFFA4659);
  static const Color moodExcited = Color(0xFFF97316);
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

/// 选择器面板的分组（仅 UI 分区，不进数据模型）。
abstract class DiaryMoodGroups {
  static const List<DiaryMood> emotions = [
    .positive,
    .neutral,
    .negative,
    .excited,
    .angry,
    .anxious,
    .tired,
    .speechless,
  ];

  static const List<DiaryMood> states = [
    .love,
    .study,
    .slacking,
    .food,
    .work,
    .travel,
    .sports,
    .sick,
  ];
}

extension DiaryMoodVisuals on DiaryMood {
  Color get color => switch (this) {
    .positive => AppColor.moodPositive,
    .neutral => AppColor.moodNeutral,
    .negative => AppColor.moodNegative,
    .excited => AppColor.moodExcited,
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
    .excited => LucideIcons.partyPopper,
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
    .excited => 'party-popper',
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

  String label(BuildContext context) => switch (this) {
    .positive => context.l10n.common.moodPositive,
    .neutral => context.l10n.common.moodNeutral,
    .negative => context.l10n.common.moodNegative,
    .excited => context.l10n.common.moodExcited,
    .angry => context.l10n.common.moodAngry,
    .anxious => context.l10n.common.moodAnxious,
    .tired => context.l10n.common.moodTired,
    .speechless => context.l10n.common.moodSpeechless,
    .love => context.l10n.common.moodLove,
    .study => context.l10n.common.moodStudy,
    .slacking => context.l10n.common.moodSlacking,
    .food => context.l10n.common.moodFood,
    .work => context.l10n.common.moodWork,
    .travel => context.l10n.common.moodTravel,
    .sports => context.l10n.common.moodSports,
    .sick => context.l10n.common.moodSick,
  };
}
