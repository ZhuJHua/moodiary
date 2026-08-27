// 2.8.0 之前的 Isar collection 定义（引擎搬迁的只读留底）。
// ⚠️ 逐字节冻结：schema 由「注册顺序 + 字段形状」决定（位置即地址），任何改动都会
// 让旧库被错误解读。新世界的模型在 moodiary_models，这里永不跟进。

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

  @Index()
  String get level => parentId ?? 'root';

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
