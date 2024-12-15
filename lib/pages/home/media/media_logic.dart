import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/media_type.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../utils/file_util.dart';
import '../../../utils/media_util.dart';
import '../../../utils/notice_util.dart';
import 'media_state.dart';

class MediaLogic extends GetxController with GetSingleTickerProviderStateMixin {
  final MediaState state = MediaState();
  late final AnimationController animationController = AnimationController(vsync: this);
  late final ItemScrollController itemScrollController = ItemScrollController();
  late final ScrollOffsetController scrollOffsetController = ScrollOffsetController();
  late final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
  late final ScrollOffsetListener scrollOffsetListener = ScrollOffsetListener.create();

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
  Future<void> getFilePath(MediaType mediaType, {bool isInit = true}) async {
    if (!isInit) {
      state.isFetching = true;
      update();
    }
    state.datetimeMediaMap = await compute(
        switch (mediaType) {
          MediaType.image => MediaUtil.groupImageFileByDate,
          MediaType.audio => MediaUtil.groupAudioFileByDate,
          MediaType.video => MediaUtil.groupVideoFileByDate,
        },
        await FileUtil.getDirFilePath(mediaType.value));
    state.dateTimeList = state.datetimeMediaMap.keys.toList();
    state.isFetching = false;
    update();
  }

  Future<void> changeMediaType(MediaType mediaType) async {
    state.mediaType.value = mediaType;
    await getFilePath(mediaType, isInit: false);
  }

  // 跳转到指定日期
  void jumpTo(DateTime dateTime) {
    final index = state.dateTimeList.indexWhere((element) => element == dateTime);
    itemScrollController.scrollTo(index: index, duration: const Duration(seconds: 1), curve: Curves.easeInOutQuart);
  }

  // 清理文件
  Future<void> cleanFile() async {
    state.isCleaning = true;
    update(['modal']);
    await FileUtil.cleanFile(FileUtil.getRealPath('database', ''));
    await getFilePath(state.mediaType.value);
    state.isCleaning = false;
    update(['modal']);
    NoticeUtil.showToast('清理成功');
  }
}
