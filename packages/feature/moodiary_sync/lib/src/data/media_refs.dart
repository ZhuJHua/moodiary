import 'package:moodiary_models/moodiary_models.dart';

/// 视频文件名 `video-<uuid>.mp4` → 缩略图名 `thumbnail-<uuid>.jpeg`。
String? videoThumbnailName(String videoName) {
  if (!videoName.startsWith('video-')) return null;
  final dotIdx = videoName.lastIndexOf('.');
  if (dotIdx <= 6) return null;
  return 'thumbnail-${videoName.substring(6, dotIdx)}.jpeg';
}

/// 收集日记引用的全部媒体文件条目 (type, filename)，含视频缩略图。
List<(String, String)> collectDiaryMediaEntries(Diary diary) {
  final entries = <(String, String)>[];
  for (final name in diary.imageName) {
    entries.add(('image', name));
  }
  for (final name in diary.audioName) {
    entries.add(('audio', name));
  }
  for (final name in diary.videoName) {
    entries.add(('video', name));
    final thumb = videoThumbnailName(name);
    if (thumb != null) entries.add(('video', thumb));
  }
  return entries;
}
