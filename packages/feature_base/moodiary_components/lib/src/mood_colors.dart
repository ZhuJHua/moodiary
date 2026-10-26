import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

import 'mood_palette.dart';

extension DiaryMoodAppearance on DiaryMood {
  Color colorOf(BuildContext context, {MoodPalette? palette}) =>
      (palette ?? MoodPalette.of(context)).color(this, context.theme.colors);

  Color onColorOf(BuildContext context, {MoodPalette? palette}) =>
      (palette ?? MoodPalette.of(context)).onColor(this, context.theme.colors);

  String labelOf(Translations l10n) => switch (this) {
    .awful => l10n.common.moodAwful,
    .bad => l10n.common.moodBad,
    .okay => l10n.common.moodOkay,
    .good => l10n.common.moodGood,
    .great => l10n.common.moodGreat,
  };

  String label(BuildContext context) => labelOf(context.l10n);
}

extension LegacyMoodSceneLabel on LegacyMoodScene {
  String labelOf(Translations l10n) => switch (this) {
    .study => l10n.common.legacySceneStudy,
    .work => l10n.common.legacySceneWork,
    .travel => l10n.common.legacySceneTravel,
    .sports => l10n.common.legacySceneSports,
    .food => l10n.common.legacySceneFood,
    .slacking => l10n.common.legacySceneSlacking,
  };
}

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
