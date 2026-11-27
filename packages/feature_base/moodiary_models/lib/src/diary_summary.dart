import 'package:freezed_annotation/freezed_annotation.dart';

import 'diary_mood.dart';

part 'diary_summary.freezed.dart';

@freezed
abstract class DiaryVisualMedia with _$DiaryVisualMedia {
  const factory DiaryVisualMedia({
    required String name,
    required bool isVideo,
  }) = _DiaryVisualMedia;
}

@freezed
class DiarySummary with _$DiarySummary {
  DiarySummary({
    required this.id,
    required this.title,
    required this.contentPreview,
    required this.time,
    required this.lastModified,
    this.mood,
    this.weatherIcon,
    this.weatherTemp,
    this.placeId,
    this.aspect,
    required List<DiaryVisualMedia> visualMedia,
    required this.moreVisualCount,
    required this.audioCount,
    required this.fileCount,
  }) : visualMedia = List.unmodifiable(visualMedia);

  final String id;
  final String title;
  final String contentPreview;
  final DateTime time;
  final DateTime lastModified;
  final DiaryMood? mood;
  final String? weatherIcon;
  final String? weatherTemp;
  final String? placeId;
  final double? aspect;
  final List<DiaryVisualMedia> visualMedia;
  final int moreVisualCount;
  final int audioCount;
  final int fileCount;
}
