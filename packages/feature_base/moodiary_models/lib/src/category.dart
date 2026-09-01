import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'utc_date_time_converter.dart';

part 'category.freezed.dart';
part 'category.g.dart';

@freezed
abstract class Category with _$Category {
  const factory Category({
    required String id,
    required String categoryName,
    @UtcDateTimeConverter() required DateTime lastModified,
    String? parentId,

    /// 卡片/标签用的 ARGB 颜色；null = 未设置（由 categoryColorOf 回退到派生色）。
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

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
