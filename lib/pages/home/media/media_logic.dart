import 'package:flutter/animation.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/media_type.dart';
import 'package:mood_diary/router/app_routes.dart';

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

    await FileUtil.cleanFile();
    await getFilePath(state.mediaType.value);
    state.isCleaning = false;
    update(['modal']);
    NoticeUtil.showToast('清理成功');
  }
}
