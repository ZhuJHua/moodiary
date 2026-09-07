import 'package:freezed_annotation/freezed_annotation.dart';

import 'category.dart';

part 'category_event.freezed.dart';

@freezed
sealed class CategoryEvent with _$CategoryEvent {
  const factory CategoryEvent.upserted(
    Category category, {
    @Default(false) bool fromSync,
  }) = CategoryUpserted;

  const factory CategoryEvent.deleted(
    String id, {
    @Default(false) bool fromSync,
  }) = CategoryDeleted;
}
