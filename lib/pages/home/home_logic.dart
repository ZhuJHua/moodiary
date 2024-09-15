import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mood_diary/pages/home/diary/diary_logic.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';

import 'home_state.dart';

class HomeLogic extends GetxController with GetSingleTickerProviderStateMixin {
  final HomeState state = HomeState();

  //fab动画控制器
  late AnimationController fabAnimationController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

  //fab动画插值器
  late Animation<double> fabAnimation =
      Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: fabAnimationController, curve: Curves.easeInOut));

  late PageController pageController = PageController();

  late final DiaryLogic diaryLogic = Bind.find<DiaryLogic>();

  @override
  void onInit() {
    // TODO: implement onInit

    super.onInit();
  }

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    fabAnimationController.dispose();
    pageController.dispose();
    super.onClose();
  }

  //打开fab
  Future<void> openFab() async {
    await HapticFeedback.vibrate();
    state.isFabExpanded.value = true;
    await fabAnimationController.forward();
  }

  //关闭fab
  Future<void> closeFab() async {
    await HapticFeedback.selectionClick();
    await fabAnimationController.reverse();
    state.isFabExpanded.value = false;
  }

  //锁定屏幕
  void lockPage() {
    //如果开启密码的同时开启了立即锁定，就直接跳转到锁屏页面
    if (Utils().prefUtil.getValue<bool>('lock') == true && Utils().prefUtil.getValue<bool>('lockNow') == true) {
      Get.toNamed(AppRoutes.lockPage, arguments: 'pause');
    }
  }

  void toUserPage() {
    //如果已经登录
    if (Utils().supabaseUtil.user != null || Utils().supabaseUtil.session != null) {
      Get.toNamed(AppRoutes.userPage);
    } else {
      Get.toNamed(AppRoutes.loginPage);
    }
  }

  //新增一篇日记
  Future<void> toEditPage() async {
    //同时关闭fab
    await HapticFeedback.selectionClick();
    //等待跳转，返回后刷新
    await Get.toNamed(AppRoutes.editPage, arguments: 'new');
    await diaryLogic.updateDiary();
    fabAnimationController.reset();
    state.isFabExpanded.value = false;
  }

  // 切换导航栏
  void changeNavigator(int index) {
    state.navigatorIndex.value = index;
    pageController.jumpToPage(index);
    update();
  }
}
