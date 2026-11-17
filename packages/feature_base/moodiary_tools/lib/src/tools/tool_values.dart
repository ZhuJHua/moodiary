import 'package:moodiary_models/moodiary_models.dart';

typedef ToolIntRange = ({int fallback, int min, int max});

const pageLimit = (fallback: 20, min: 1, max: 100);
const pageOffset = (fallback: 0, min: 0, max: 1000000);
const tagLimit = (fallback: 50, min: 1, max: 500);
const statsMonths = (fallback: 12, min: 1, max: 120);
const imageWidth = (fallback: 100, min: 10, max: 100);

final toolMoodNames = [for (final mood in DiaryMood.values) mood.name];

DiaryMood? toolMood(Object? value) {
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return DiaryMood.fromScore(value.toInt());
  }
  if (value is! String) return null;
  final text = value.trim().toLowerCase();
  return DiaryMood.fromName(text) ??
      DiaryMood.fromScore(int.tryParse(text) ?? 0);
}
