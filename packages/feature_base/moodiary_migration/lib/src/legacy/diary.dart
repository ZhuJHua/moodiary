// 字段顺序/形状即 isar 编码地址，改动会读坏旧库

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart'
    show DiaryType, UtcDateTimeConverter;
import 'package:moodiary_utils/moodiary_utils.dart';

part 'diary.freezed.dart';
part 'diary.g.dart';

@freezed
@Collection(ignore: {'copyWith'})
abstract class Diary with _$Diary {
  const factory Diary({
    required String id,
    @Index() String? categoryId,
    required String title,
    required String content,
    required String contentText,
    @Index() @UtcDateTimeConverter() required DateTime time,
    @UtcDateTimeConverter() required DateTime lastModified,
    @Index() required bool show,
    required double mood,
    required List<String> weather,
    required List<String> imageName,
    required List<String> audioName,
    required List<String> videoName,
    required List<String> tags,
    required List<String> position,
    required String type,
    double? aspect,
  }) = _Diary;

  const Diary._();

  // this.id 须显式限定：isar_plus 顶层 const id 会掩盖 freezed 的 id
  @Id()
  int get isarId => fastHash(this.id);

  factory Diary.create({
    String? categoryId,
    required String title,
    required String content,
    required String contentText,
    required double mood,
    required List<String> weather,
    required List<String> imageName,
    required List<String> audioName,
    required List<String> videoName,
    required List<String> tags,
    required List<String> position,
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
      position: position,
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
      mood: 0.5,
      weather: [],
      imageName: [],
      audioName: [],
      videoName: [],
      tags: [],
      position: [],
      type: type.value,
    );
  }

  factory Diary.fromJson(Map<String, dynamic> json) => _$DiaryFromJson(json);
}
