import 'package:moodiary_models/moodiary_models.dart';

import 'diary_content.dart';

Diary withDerivedMedia(Diary d) {
  final media = DiaryContent.of(d).media;
  return d.copyWith(
    imageName: media.images,
    videoName: media.videos,
    audioName: media.audios,
  );
}

Diary touched(Diary d) => d.copyWith(lastModified: .timestamp());
