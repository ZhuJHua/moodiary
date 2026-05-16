import 'package:flutter/material.dart';
import 'package:moodiary/l10n/l10n.dart';

class WeatherPreset {
  final String code;
  final String nameKey;
  const WeatherPreset(this.code, this.nameKey);
}

const kWeatherPresets = <WeatherPreset>[
  WeatherPreset('100', 'weatherSunny'),
  WeatherPreset('101', 'weatherCloudy'),
  WeatherPreset('104', 'weatherOvercast'),
  WeatherPreset('300', 'weatherShowerRain'),
  WeatherPreset('305', 'weatherLightRain'),
  WeatherPreset('306', 'weatherModerateRain'),
  WeatherPreset('307', 'weatherHeavyRain'),
  WeatherPreset('302', 'weatherThunder'),
  WeatherPreset('400', 'weatherLightSnow'),
  WeatherPreset('401', 'weatherModerateSnow'),
  WeatherPreset('402', 'weatherHeavySnow'),
  WeatherPreset('501', 'weatherFog'),
  WeatherPreset('502', 'weatherHaze'),
  WeatherPreset('507', 'weatherSandstorm'),
];

extension WeatherPresetL10n on WeatherPreset {
  String label(BuildContext c) => switch (nameKey) {
        'weatherSunny' => c.l10n.weatherSunny,
        'weatherCloudy' => c.l10n.weatherCloudy,
        'weatherOvercast' => c.l10n.weatherOvercast,
        'weatherShowerRain' => c.l10n.weatherShowerRain,
        'weatherLightRain' => c.l10n.weatherLightRain,
        'weatherModerateRain' => c.l10n.weatherModerateRain,
        'weatherHeavyRain' => c.l10n.weatherHeavyRain,
        'weatherThunder' => c.l10n.weatherThunder,
        'weatherLightSnow' => c.l10n.weatherLightSnow,
        'weatherModerateSnow' => c.l10n.weatherModerateSnow,
        'weatherHeavySnow' => c.l10n.weatherHeavySnow,
        'weatherFog' => c.l10n.weatherFog,
        'weatherHaze' => c.l10n.weatherHaze,
        'weatherSandstorm' => c.l10n.weatherSandstorm,
        _ => nameKey,
      };
}
