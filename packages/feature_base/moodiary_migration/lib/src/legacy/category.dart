// 字段顺序/形状即 isar 编码地址，改动会读坏旧库

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart' show UtcDateTimeConverter;
import 'package:moodiary_utils/moodiary_utils.dart';

part 'category.freezed.dart';
part 'category.g.dart';

@freezed
@Collection(ignore: {'copyWith'})
abstract class Category with _$Category {
  const factory Category({
    @Id() required String id,
    required String categoryName,
    @UtcDateTimeConverter() required DateTime lastModified,
    String? parentId,

    int? color,
  }) = _Category;

  const Category._();

  factory Category.create({
    required String categoryName,
    String? parentId,
    int? color,
  }) {
    return Category(
      id: uuidV7(),
      categoryName: categoryName,
      lastModified: .timestamp(),
      parentId: parentId,
      color: color,
    );
  }

  @Index()
  String get level => parentId ?? 'root';

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
