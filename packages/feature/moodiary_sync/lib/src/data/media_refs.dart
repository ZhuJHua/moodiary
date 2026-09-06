import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';

String? videoThumbnailName(String videoName) =>
    AppFiles.thumbnailNameOf(videoName);

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
