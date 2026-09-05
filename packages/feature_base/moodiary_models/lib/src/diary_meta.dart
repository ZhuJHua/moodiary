import 'package:freezed_annotation/freezed_annotation.dart';

part 'diary_meta.freezed.dart';
part 'diary_meta.g.dart';

/// 日记天气。旧模型是 `List<String>` 定长元组（`[图标码, 温度, 描述]`）。
///
/// [temp] 是**可空**的：和风实时接口拿回来的带温度，用户在属性头手选的那 16 个
/// 常见天气只有码与描述、没有温度。字符串而非数字是沿用和风的原样存取（数字字符串、
/// 摄氏度、不带单位）。展示一律走 [DiaryWeatherDisplay]，别在调用点自己拼 `°`。
@freezed
abstract class DiaryWeather with _$DiaryWeather {
  const factory DiaryWeather({
    /// 和风天气图标码（如 `"100"`）。
    required String icon,

    /// 摄氏温度的数字字符串；null = 手选天气，没有温度。
    String? temp,

    /// 文字描述（如「晴」/「多云」）。
    required String text,
  }) = _DiaryWeather;

  factory DiaryWeather.fromJson(Map<String, dynamic> json) =>
      _$DiaryWeatherFromJson(json);
}

/// 天气的展示串。**全仓只有这一处拼温度** —— 手选天气没有温度，六个展示点各拼各的
/// 必然漏，漏一处就是「晴 °」。空串与 null 同等对待（旧库迁移可能留下空串）。
extension DiaryWeatherDisplay on DiaryWeather {
  /// 完整形式：「多云 18°」/ 无温度时「多云」。
  String get displayText {
    final t = temp;
    return (t == null || t.isEmpty) ? text : '$text $t°';
  }

  /// 紧凑形式（图标已经表达了天气，旁边只补温度）：「18°」/ 无温度时回退「多云」。
  String get compactText {
    final t = temp;
    return (t == null || t.isEmpty) ? text : '$t°';
  }
}
