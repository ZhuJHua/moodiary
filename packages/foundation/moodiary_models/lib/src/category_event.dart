import 'package:freezed_annotation/freezed_annotation.dart';
import 'category.dart';

part 'category_event.freezed.dart';

/// 分类没有硬删除：软删（`deleted = true`）与同步 tombstone 都归 [CategoryUpserted]
/// （列表按 `!deleted` 决定迁入 / 迁出）；[CategoryDeleted] 仅用于 UI 软删后从列表移除。
@freezed
sealed class CategoryEvent with _$CategoryEvent {
  const factory CategoryEvent.upserted(Category category) = CategoryUpserted;

  const factory CategoryEvent.deleted(String id) = CategoryDeleted;
}
