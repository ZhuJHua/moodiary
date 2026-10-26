import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diary_meta_references.g.dart';

typedef DiaryMetaReferences = ({
  Category? category,
  Place? place,
  List<Place> places,
  bool ready,
});

// 同步读缓存，所需引用首次就绪后再显示编辑器；刷新时沿用旧值，读取失败按缺失处理
@riverpod
DiaryMetaReferences diaryMetaReferences(
  Ref ref, {
  String? categoryId,
  String? placeId,
}) {
  final categories = ref.watch(categoryControllerProvider);
  final category = ref.watch(categoryByIdProvider(categoryId));
  final placesAsync = ref.watch(orderedPlacesProvider);
  final places = placesAsync.hasError
      ? const <Place>[]
      : placesAsync.value ?? const <Place>[];
  final categoryLoading =
      categoryId != null && !categories.hasValue && !categories.hasError;
  final placeLoading =
      placeId != null && !placesAsync.hasValue && !placesAsync.hasError;
  return (
    category: categories.hasError ? null : category,
    place: places.where((p) => p.id == placeId).firstOrNull,
    places: places,
    ready: !categoryLoading && !placeLoading,
  );
}
