import 'dart:async';

import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'diary_repository.dart';
import 'place_repository.dart';

part 'place_controller.g.dart';

List<Place> _applyEvent(List<Place> list, PlaceEvent event) {
  switch (event) {
    case PlaceDeleted(:final id):
      if (!list.any((p) => p.id == id)) return list;
      return list.where((p) => p.id != id).toList();
    case PlaceUpserted(:final place):
      final index = list.indexWhere((p) => p.id == place.id);
      final updated = [...list];
      if (index == -1) {
        updated.add(place);
      } else {
        updated[index] = place;
      }
      updated.sort((a, b) => a.id.compareTo(b.id));
      return updated;
  }
}

@riverpod
class PlaceController extends _$PlaceController {
  late final _repository = getIt<PlaceRepository>();

  bool _missedEvent = false;

  @override
  FutureOr<List<Place>> build() async {
    final sub = _repository.placeEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    var list = await _repository.getAllPlaces();
    for (var i = 0; _missedEvent && i < 3; i++) {
      _missedEvent = false;
      list = await _repository.getAllPlaces();
    }
    return list;
  }

  void _applyChange(PlaceEvent event) {
    final list = state.value;
    if (list == null) {
      _missedEvent = true;
      return;
    }
    state = .data(_applyEvent(list, event));
  }

  Future<bool> upsertPlace(Place place) async {
    try {
      await _repository.insertAPlace(place);
      return true;
    } catch (e, s) {
      logger.e('upsert place failed', error: e, stackTrace: s);
      return false;
    }
  }

  Future<bool> deletePlace(String id) async {
    try {
      return await _repository.deleteAPlace(id);
    } catch (e, s) {
      logger.e('delete place failed', error: e, stackTrace: s);
      return false;
    }
  }
}

@riverpod
AsyncValue<List<Place>> orderedPlaces(Ref ref) {
  final orderNotifier = MoodiaryKVs.placeOrder.getNotifierOr(const <String>[]);
  void onOrderChanged() => ref.invalidateSelf();
  orderNotifier.addListener(onOrderChanged);
  ref.onDispose(() => orderNotifier.removeListener(onOrderChanged));
  final async = ref.watch(placeControllerProvider);
  return async.whenData(
    (places) => applyPlaceOrder(places, orderNotifier.value),
  );
}

List<Place> applyPlaceOrder(List<Place> places, List<String> order) {
  if (order.isEmpty) return places;
  final byId = {for (final p in places) p.id: p};
  final result = <Place>[];
  for (final id in order) {
    final p = byId.remove(id);
    if (p != null) result.add(p);
  }
  result.addAll(byId.values.toList()..sort((a, b) => a.id.compareTo(b.id)));
  return result;
}

@riverpod
Place? placeById(Ref ref, String? id) {
  if (id == null) return null;
  final places = ref.watch(placeControllerProvider).value ?? const [];
  for (final p in places) {
    if (p.id == id) return p;
  }
  return null;
}

@riverpod
Future<Map<String, int>> placeDiaryCounts(Ref ref) async {
  final diaryRepo = getIt<DiaryRepository>();
  Timer? debounce;
  final sub = diaryRepo.diaryEvents.listen((_) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 200), ref.invalidateSelf);
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });
  return diaryRepo.diaryCountByPlace();
}
