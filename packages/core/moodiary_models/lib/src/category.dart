import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_rust/moodiary_rust.dart';

import 'utc_date_time_converter.dart';

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

    /// 卡片/标签用的 ARGB 颜色；null = 未设置（由 categoryColorOf 回退到派生色）。
    int? color,

    /// 软删除标记（仅用于同步传播；本地 UI 经 `getAllCategories()` 过滤）。
    /// 无 model 级默认值：旧库（<2.8.0）的回填由 [MergeUtil] 迁移显式写入。
    @Index() required bool deleted,
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
      lastModified: DateTime.timestamp(),
      parentId: parentId,
      color: color,
      deleted: false,
    );
  }

  @Index()
  String get level => parentId ?? 'root';

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
