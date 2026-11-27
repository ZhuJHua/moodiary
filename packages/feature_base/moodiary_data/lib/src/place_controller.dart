import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'data_providers.dart';
import 'diary_repository.dart' show PlaceFootprint;
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
  late PlaceRepository _repository;

  bool _missedEvent = false;

  @override
  FutureOr<List<Place>> build() async {
    final operationRef = ref;
    final repository = ref.watch(placeRepositoryProvider);
    _repository = repository;
    final sub = repository.placeEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    var list = await repository.getAllPlaces();
    for (var i = 0; operationRef.mounted && _missedEvent && i < 3; i++) {
      _missedEvent = false;
      list = await repository.getAllPlaces();
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

  Future<int> affectedDiaryCount(List<String> placeIds) async {
    try {
      return await ref
          .read(diaryRepositoryProvider)
          .countDiariesWithPlaceIds(placeIds);
    } catch (e, s) {
      logger.e('load affected diaries failed', error: e, stackTrace: s);
      return 0;
    }
  }

  Future<PlaceMergeRecord?> mergePlaces({
    required String keptId,
    required String finalName,
    required List<String> removedIds,
  }) async {
    try {
      return await _repository.mergePlaces(
        keptId: keptId,
        finalName: finalName,
        removedIds: removedIds,
      );
    } catch (e, s) {
      logger.e('merge places failed', error: e, stackTrace: s);
      return null;
    }
  }

  Future<bool> undoMerge(PlaceMergeRecord record) async {
    try {
      await _repository.undoMerge(record);
      return true;
    } catch (e, s) {
      logger.e('undo merge failed', error: e, stackTrace: s);
      return false;
    }
  }
}

@riverpod
AsyncValue<List<Place>> orderedPlaces(Ref ref) {
  final order = ref.watch(
    kvValueOrProvider<List<String>>(MoodiaryKVs.placeOrder, const <String>[]),
  );
  final async = ref.watch(placeControllerProvider);
  return async.whenData((places) => applyPlaceOrder(places, order));
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
Map<String, Place> placeMap(Ref ref) {
  final places = ref.watch(placeControllerProvider).value ?? const <Place>[];
  return Map.unmodifiable({for (final place in places) place.id: place});
}

@riverpod
Place? placeById(Ref ref, String? id) {
  if (id == null) return null;
  return ref.watch(placeMapProvider.select((map) => map[id]));
}

@riverpod
Future<Map<String, PlaceFootprint>> placeFootprints(Ref ref) async {
  final diaryRepo = ref.watch(diaryRepositoryProvider);
  Timer? debounce;
  final sub = diaryRepo.diaryEvents.listen((_) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 200), ref.invalidateSelf);
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });
  return diaryRepo.placeFootprints();
}
