// 2.8.0 之前的 Isar collection 定义（引擎搬迁的只读留底）。
// ⚠️ 逐字节冻结：schema 由「注册顺序 + 字段形状」决定（位置即地址），任何改动都会
// 让旧库被错误解读。新世界的模型在 moodiary_models，这里永不跟进。

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

  // `this.id` 必须显式限定：isar_plus 导出了顶层 `const id = Id()`，
  // 裸 `id` 会被解析成它而非 freezed mixin 的 `String get id`。
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

  /// 空模板。必须显式指定 [type]——禁止隐藏的默认类型，避免默认值与 UI 层
  /// post-frame `changeType` 兜底带来的时序坑。
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
