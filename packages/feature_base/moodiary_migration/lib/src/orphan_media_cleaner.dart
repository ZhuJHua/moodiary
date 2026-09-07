import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_migration/src/legacy/legacy_models.dart' as legacy;

Future<void> cleanOrphanMediaIn(String dir) async {
  // Isar.open 是 open-or-create：旧库不在时会静默新建空库，count 为 0 会导致全部媒体被误判孤儿删除。
  final isar = legacy.openLegacyIsar(
    schemas: legacy.diaryAndCategorySchemas,
    dir: dir,
  );
  if (isar == null) return;
  try {
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
  } finally {
    // isar_plus per-isolate 缓存会复用未 close 的实例并忽略新传入的 schemas。
    isar.close();
  }
}
