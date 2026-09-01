import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_migration/src/legacy/legacy_models.dart' as legacy;

Future<void> cleanOrphanMediaIn(String dir) async {
  // [openLegacyIsar] 的存在性守卫在这里是**保命**的：Isar.open 是 open-or-create，
  // 旧库不在（2.8.0 搬迁完成后被 finalizeMigration 改名成 .pre-sqlite.bak）时它会
  // 静默新建一个空库，count 为 0 →「磁盘上全部媒体」都算孤儿被物理删除，不可恢复。
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
  } finally {
    // 不 close 的话，isar_plus 的 per-isolate 缓存会让同一次启动里后续用 15 张表
    // 打开同一个库时**直接拿回这个只有 2 张表的实例并忽略传入的 schemas**，
    // 引擎搬迁走到 isar.fonts 当场抛 ArgumentError。
    isar.close();
  }
}
