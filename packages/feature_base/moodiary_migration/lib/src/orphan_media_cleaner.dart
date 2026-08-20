import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';

Future<void> cleanOrphanMediaIn(String dir) async {
  final isar = Isar.open(schemas: diaryAndCategorySchemas, directory: dir);
  final imageFiles = (await AppFiles.getDirFileName(MediaType.image.value))
      .toSet();
  final audioFiles = (await AppFiles.getDirFileName(MediaType.audio.value))
      .toSet();
  final videoFiles = (await AppFiles.getDirFileName(MediaType.video.value))
      .toSet();

  final usedImages = <String>{};
  final usedAudios = <String>{};
  final usedVideos = <String>{};

  final count = isar.diarys.count();

  const batchSize = 50;
  for (int i = 0; i < count; i += batchSize) {
    final diaryList = await isar.diarys.where().findAllAsync(
      offset: i,
      limit: batchSize,
    );
    for (final diary in diaryList) {
      usedImages.addAll(diary.imageName);
      usedAudios.addAll(diary.audioName);
      usedVideos.addAll(diary.videoName);
      for (final name in diary.videoName) {
        // 派生不出名字说明当初也生成不出缩略图，没有对应文件要保留。
        final thumbnailName = AppFiles.thumbnailNameOf(name);
        if (thumbnailName != null) usedVideos.add(thumbnailName);
      }
    }
  }

  final imagesToDelete = imageFiles.difference(usedImages);
  final audiosToDelete = audioFiles.difference(usedAudios);
  final videosToDelete = videoFiles.difference(usedVideos);

  await Future.wait([
    AppFiles.deleteMediaFiles(imagesToDelete, MediaType.image.value),
    AppFiles.deleteMediaFiles(audiosToDelete, MediaType.audio.value),
    AppFiles.deleteMediaFiles(videosToDelete, MediaType.video.value),
  ]);
}
