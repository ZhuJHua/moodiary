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
