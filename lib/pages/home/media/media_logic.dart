import 'package:flutter/animation.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/media_type.dart';
import 'package:mood_diary/components/audio_player/audio_player_logic.dart';
import 'package:mood_diary/router/app_routes.dart';

import '../../../utils/data/isar.dart';
import '../../../utils/file_util.dart';
import '../../../utils/notice_util.dart';
import 'media_state.dart';

class MediaLogic extends GetxController with GetSingleTickerProviderStateMixin {
  final MediaState state = MediaState();
  late final AnimationController animationController = AnimationController(vsync: this);

  @override
  void onReady() async {
    await getFilePath(state.mediaType.value);
    super.onReady();
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }

  /// 获取指定类型目录下的所有文件路径
  /// 目录名称和 MediaType 的 value 对应
  /// 1.图片 image
  /// 2.音频 audio
  /// 3.视频 video
  Future<void> getFilePath(MediaType mediaType) async {
    state.filePath.value = await FileUtil.getDirFilePath(mediaType.value);
  }

  Future<void> changeMediaType(MediaType mediaType) async {
    await getFilePath(mediaType);
    //如果是视频，维护一个缩略图的map
    if (mediaType == MediaType.video) {
      getVideoThumbnailMap(state.filePath.value);
    }
    state.mediaType.value = mediaType;
  }

  //点击图片跳转到图片预览页面
  void toPhotoView(int index) {
    Get.toNamed(AppRoutes.photoPage, arguments: [state.filePath, index]);
  }

  //点击视频跳转到视频预览
  void toVideoView(List<String> videoPathList, int index) {
    Get.toNamed(AppRoutes.videoPage, arguments: [videoPathList, index]);
  }

  void getVideoThumbnailMap(List<String> files) {
    // 定义两个列表来存储视频和缩略图文件
    List<String> videos = [];
    List<String> thumbnails = [];
    // 遍历文件列表，将视频和缩略图分别添加到对应的列表中
    for (var file in files) {
      if (file.endsWith(".mp4")) {
        videos.add(file);
      } else if (file.endsWith(".jpeg")) {
        thumbnails.add(file);
      }
    }
    // 创建一个map来存储缩略图和视频的映射
    Map<String, String> videoThumbnailMap = {};
    // 遍历缩略图列表，并找到对应的视频
    for (var thumbnail in thumbnails) {
      // 提取唯一标识
      var id = thumbnail.split('thumbnail-')[1].split('.jpeg')[0];
      // 查找对应的视频
      var video = videos.firstWhere((v) => v.contains(id));
      // 如果找到对应的视频，则将其添加到map中
      videoThumbnailMap[thumbnail] = video;
    }

    state.videoThumbnailMap.value = videoThumbnailMap;
  }

  // 清理文件
  Future<void> cleanFile() async {
    state.isCleaning = true;
    update(['modal']);

    // 获取各类型的所有文件路径并转换为Set以提高查找效率
    final imageFiles = (await FileUtil.getDirFileName(MediaType.image.value)).toSet();
    final audioFiles = (await FileUtil.getDirFileName(MediaType.audio.value)).toSet();
    final videoFiles = (await FileUtil.getDirFileName(MediaType.video.value)).toSet();

    // 用于存储日记中引用的文件名的Set
    final usedImages = <String>{};
    final usedAudios = <String>{};
    final usedVideos = <String>{};

    // 获取日记总数
    final count = IsarUtil.countAllDiary();

    // 分批获取日记并收集引用的文件名
    const batchSize = 50;
    for (int i = 0; i < count; i += batchSize) {
      final diaryList = await IsarUtil.getDiary(i, batchSize);
      for (var diary in diaryList) {
        usedImages.addAll(diary.imageName);
        usedAudios.addAll(diary.audioName);
        usedVideos.addAll(diary.videoName);
        for (var name in diary.videoName) {
          var thumbnailName = 'thumbnail-${name.substring(6, 42)}.jpeg';
          usedVideos.add(thumbnailName);
        }
      }
    }

    // 计算需要删除的文件
    final imagesToDelete = imageFiles.difference(usedImages);
    final audiosToDelete = audioFiles.difference(usedAudios);
    final videosToDelete = videoFiles.difference(usedVideos);

    // delete controller when need
    for (var path in audiosToDelete) {
      Bind.delete<AudioPlayerLogic>(tag: path);
    }

    // 并行删除文件
    await Future.wait([
      FileUtil.deleteMediaFiles(imagesToDelete, MediaType.image.value),
      FileUtil.deleteMediaFiles(audiosToDelete, MediaType.audio.value),
      FileUtil.deleteMediaFiles(videosToDelete, MediaType.video.value),
    ]);
    await getFilePath(state.mediaType.value);
    state.isCleaning = false;
    update(['modal']);
    NoticeUtil.showToast('清理成功');
  }
}
