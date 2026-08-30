import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

/// 心情语义色（业务色，不随主题）。三分类离散取色——
/// 旧的红绿连续插值已废（中点是脏土黄），中性用安静灰让平静日不抢视线。
abstract class AppColor {
  static const Color moodNegative = Color(0xFFFA4659);
  static const Color moodNeutral = Color(0xFF8A9099);
  static const Color moodPositive = Color(0xFF2EB872);
}

extension DiaryMoodVisuals on DiaryMood {
  Color get color => switch (this) {
    .negative => AppColor.moodNegative,
    .neutral => AppColor.moodNeutral,
    .positive => AppColor.moodPositive,
  };

  IconData get icon => switch (this) {
    .negative => LucideIcons.frown,
    .neutral => LucideIcons.meh,
    .positive => LucideIcons.smile,
  };

  String label(BuildContext context) => switch (this) {
    .negative => context.l10n.common.moodNegative,
    .neutral => context.l10n.common.moodNeutral,
    .positive => context.l10n.common.moodPositive,
  };
}
