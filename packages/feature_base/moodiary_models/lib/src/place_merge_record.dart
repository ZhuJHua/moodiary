import 'place.dart';

class PlaceMergeRecord {
  final Place kept;
  final List<Place> removed;
  final Map<String, String> diaryRemap;

  const PlaceMergeRecord({
    required this.kept,
    required this.removed,
    required this.diaryRemap,
  });
}
