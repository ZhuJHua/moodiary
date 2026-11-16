import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

class StubPlaceController extends PlaceController {
  StubPlaceController(this._places);

  final List<Place> _places;

  ({String keptId, String finalName, List<String> removedIds})? merged;
  int undoCalls = 0;
  int affectedCount = 0;
  bool mergeOk = true;
  bool undoOk = true;
  bool disposed = false;
  PlaceMergeRecord? undoneRecord;

  @override
  Future<List<Place>> build() async {
    ref.onDispose(() => disposed = true);
    return _places;
  }

  @override
  Future<int> affectedDiaryCount(List<String> placeIds) async => affectedCount;

  @override
  Future<PlaceMergeRecord?> mergePlaces({
    required String keptId,
    required String finalName,
    required List<String> removedIds,
  }) async {
    merged = (keptId: keptId, finalName: finalName, removedIds: removedIds);
    if (!mergeOk) return null;
    state = AsyncData([
      for (final place in _places)
        if (!removedIds.contains(place.id))
          place.id == keptId ? place.copyWith(name: finalName) : place,
    ]);
    return PlaceMergeRecord(
      kept: _places.firstWhere((place) => place.id == keptId),
      removed: [
        for (final place in _places)
          if (removedIds.contains(place.id)) place,
      ],
      diaryRemap: const {},
    );
  }

  @override
  Future<bool> undoMerge(PlaceMergeRecord record) async {
    undoCalls++;
    undoneRecord = record;
    if (!undoOk) return false;
    if (!disposed) state = AsyncData(_places);
    return true;
  }
}
