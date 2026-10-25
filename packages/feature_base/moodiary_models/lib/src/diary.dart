import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'diary_meta.dart';
import 'diary_mood.dart';
import 'diary_type.dart';
import 'utc_date_time_converter.dart';

part 'diary.freezed.dart';
part 'diary.g.dart';

@freezed
abstract class Diary with _$Diary {
  const factory Diary({
    required String id,
    String? categoryId,
    required String title,
    required String content,
    required String contentText,
    @UtcDateTimeConverter() required DateTime time,
    @UtcDateTimeConverter() required DateTime lastModified,
    required bool show,
    DiaryMood? mood,
    DiaryWeather? weather,
    required List<String> imageName,
    required List<String> audioName,
    required List<String> videoName,
    @Default(<String>[]) List<String> fileName,
    required List<String> tags,

    String? placeId,
    required String type,
    double? aspect,
  }) = _Diary;

  const Diary._();

  factory Diary.create({
    String? categoryId,
    required String title,
    required String content,
    required String contentText,
    DiaryMood? mood,
    DiaryWeather? weather,
    required List<String> imageName,
    required List<String> audioName,
    required List<String> videoName,
    required List<String> tags,
    String? placeId,
    required DiaryType type,
    double? aspect,
  }) {
    return Diary(
      id: uuidV7(),
      categoryId: categoryId,
      title: title,
      content: content,
      contentText: contentText,
      time: .timestamp(),
      lastModified: .timestamp(),
      show: true,
      mood: mood,
      weather: weather,
      imageName: imageName,
      audioName: audioName,
      videoName: videoName,
      tags: tags,
      placeId: placeId,
      type: type.value,
      aspect: aspect,
    );
  }

  factory Diary.empty({required DiaryType type}) {
    return Diary(
      id: uuidV7(),
      title: '',
      content: '',
      contentText: '',
      time: .timestamp(),
      lastModified: .timestamp(),
      show: true,
      mood: null,
      imageName: [],
      audioName: [],
      videoName: [],
      tags: [],
      type: type.value,
    );
  }

  factory Diary.fromJson(Map<String, dynamic> json) => _$DiaryFromJson(json);
}
