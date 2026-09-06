import 'package:freezed_annotation/freezed_annotation.dart';

part 'diary_meta.freezed.dart';
part 'diary_meta.g.dart';

@freezed
abstract class DiaryWeather with _$DiaryWeather {
  const factory DiaryWeather({
    required String icon,

    String? temp,

    required String text,
  }) = _DiaryWeather;

  factory DiaryWeather.fromJson(Map<String, dynamic> json) =>
      _$DiaryWeatherFromJson(json);
}

extension DiaryWeatherDisplay on DiaryWeather {
  String get displayText {
    final t = temp;
    return (t == null || t.isEmpty) ? text : '$text $t°';
  }

  String get compactText {
    final t = temp;
    return (t == null || t.isEmpty) ? text : '$t°';
  }
}
