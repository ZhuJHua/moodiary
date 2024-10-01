import 'package:get/get.dart';
import 'package:mood_diary/common/values/media_type.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';

import 'media_state.dart';

class MediaLogic extends GetxController {
  final MediaState state = MediaState();

  @override
  void onReady() async {
    await getFilePath(state.mediaType.value);
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  /// 获取指定类型目录下的所有文件路径
  /// 目录名称和 MediaType 的 value 对应
  /// 1.图片 image
  /// 2.音频 audio
  /// 3.视频 video
  Future<void> getFilePath(MediaType mediaType) async {
    state.filePath.value = await Utils().fileUtil.getDirFilePath(mediaType.value);
  }

  Future<void> changeMediaType(MediaType mediaType) async {
    state.mediaType.value = mediaType;
  }

  //点击图片跳转到图片预览页面
  void toPhotoView(int index) {
    Get.toNamed(AppRoutes.photoPage, arguments: [state.filePath.value, index]);
  }

  // 清理文件
  Future<void> cleanFile() async {
    state.isCleaning.value = true;
    final fileUtil = Utils().fileUtil;
    final isarUtil = Utils().isarUtil;

    // 获取各类型的所有文件路径并转换为Set以提高查找效率
    final imageFiles = (await fileUtil.getDirFileName(MediaType.image.value)).toSet();
    final audioFiles = (await fileUtil.getDirFileName(MediaType.audio.value)).toSet();
    final videoFiles = (await fileUtil.getDirFileName(MediaType.video.value)).toSet();

    // 用于存储日记中引用的文件名的Set
    final usedImages = <String>{};
    final usedAudios = <String>{};
    final usedVideos = <String>{};

    // 获取日记总数
    final count = isarUtil.countAllDiary();

    // 分批获取日记并收集引用的文件名
    const batchSize = 50;
    for (int i = 0; i < count; i += batchSize) {
      final diaryList = await isarUtil.getDiary(i, batchSize);
      for (var diary in diaryList) {
        usedImages.addAll(diary.imageName);
        usedAudios.addAll(diary.audioName);
        usedVideos.addAll(diary.videoName);
      }
    }

    // 计算需要删除的文件
    final imagesToDelete = imageFiles.difference(usedImages);
    final audiosToDelete = audioFiles.difference(usedAudios);
    final videosToDelete = videoFiles.difference(usedVideos);

    // 并行删除文件
    await Future.wait([
      fileUtil.deleteMediaFiles(imagesToDelete, MediaType.image.value),
      fileUtil.deleteMediaFiles(audiosToDelete, MediaType.audio.value),
      fileUtil.deleteMediaFiles(videosToDelete, MediaType.video.value),
    ]);
    await getFilePath(state.mediaType.value);
    state.isCleaning.value = false;
  }
}
