import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 按日记引用扫一遍媒体目录，删掉没人引用的文件。
///
/// 这段原本住在 `moodiary_core` 的 `AppFiles` 里，但它读的是 Diary 行——core 是无领域
/// 层，不认识 Diary，所以它跟着唯一的调用方（版本迁移）上来了。
///
/// [dir] 是要挂载的数据库目录。用 [diaryAndCategorySchemas] 而不是字面量：isar_plus
/// 按位置下标寻址 collection，子集必须是 `moodiarySchemas` 的严格前缀。
Future<void> cleanOrphanMediaIn(String dir) async {
  final isar = Isar.open(
    schemas: diaryAndCategorySchemas,
    directory: dir,
  );
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
