/// 属性头手选天气的候选集：16 个和风官方码，4×4 一屏铺完（与心情面板同栅格）。
///
/// **为什么不是和风全部 400+ 个码**：「少云 / 晴间多云」「小到中雨 / 中到大雨」是
/// 预报语义，人手选时只增加犹豫不增加表达力；夜间变体（150/151/350…）在手选场景
/// 自证多余——写日记的人知道现在是夜里。自动获取那条链路仍然接受**全部**码，
/// 和风返回什么就存什么，图标字体本来就全带着。
///
/// [code] 即 [DiaryWeather.icon]，两端的图标字体都按它取字形（Flutter 侧
/// `qweatherIcon`，web 侧 qweather-icons 的码表）。名称是本地化的，取串见
/// `moodiary_components` 的 `ManualWeatherLabel`。
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

  /// 和风天气码。
  final String code;

  /// 码 → 候选项；不在这 16 个里（自动获取拿到的其它码）返回 null。
  static ManualWeather? fromCode(String code) {
    for (final w in values) {
      if (w.code == code) return w;
    }
    return null;
  }
}
