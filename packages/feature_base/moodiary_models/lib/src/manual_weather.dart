enum ManualWeather {
  sunny('100'),
  cloudy('101'),
  overcast('104'),
  showerRain('300'),
  lightRain('305'),
  moderateRain('306'),
  heavyRain('307'),
  storm('310'),
  thundershower('302'),
  lightSnow('400'),
  heavySnow('402'),
  sleet('404'),
  foggy('501'),
  haze('502'),
  hot('900'),
  cold('901');

  const ManualWeather(this.code);

  final String code;

  static ManualWeather? fromCode(String code) {
    for (final w in values) {
      if (w.code == code) return w;
    }
    return null;
  }
}
