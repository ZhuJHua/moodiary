import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/router/app_routes.dart';

import '../../utils/data/isar.dart';
import 'diary_details_state.dart';

class DiaryDetailsLogic extends GetxController {
  final DiaryDetailsState state = DiaryDetailsState();

  // 编辑器控制器
  late QuillController quillController = QuillController(
    document: Document.fromJson(jsonDecode(state.diary.content)),
    readOnly: true,
    selection: const TextSelection.collapsed(offset: 0),
  );

  // 图片预览
  late final PageController pageController = PageController();

  @override
  void onClose() {
    quillController.dispose();
    pageController.dispose();
    super.onClose();
  }

  //点击图片跳转到图片预览页面
  void toPhotoView(List<String> imagePathList, int index) {
    HapticFeedback.selectionClick();
    Get.toNamed(AppRoutes.photoPage, arguments: [imagePathList, index]);
  }

  //点击视频跳转到视频预览页面
  void toVideoView(List<String> videoPathList, int index) {
    Get.toNamed(AppRoutes.videoPage, arguments: [videoPathList, index]);
  }

  //点击分享跳转到分享页面
  Future<void> toSharePage() async {
    Get.toNamed(AppRoutes.sharePage, arguments: state.diary);
  }

  //编辑日记
  Future<void> toEditPage(Diary diary) async {
    //这里参数为diary，表示编辑日记，等待跳转结果为changed，重新获取日记
    if ((await Get.toNamed(AppRoutes.editPage, arguments: diary.clone())) ==
        'changed') {
      //重新获取日记
      state.diary = (await IsarUtil.getDiaryByID(state.diary.isarId))!;
      quillController = QuillController(
        document: Document.fromJson(jsonDecode(state.diary.content)),
        readOnly: true,
        selection: const TextSelection.collapsed(offset: 0),
      );
      update();
    }
  }

  //放入回收站
  Future<void> delete(Diary diary) async {
    var newDiary = diary.clone()..show = false;
    await IsarUtil.updateADiary(oldDiary: diary, newDiary: newDiary);
    Get.backLegacy(result: 'delete');
  }

  Future<void> jumpToPage(int index) async {
    await pageController.animateToPage(index,
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
  }
}
