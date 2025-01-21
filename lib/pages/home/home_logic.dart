import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/components/frosted_glass_overlay/frosted_glass_overlay_logic.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/data/pref.dart';
import 'package:moodiary/utils/data/supabase.dart';
import 'package:refreshed/refreshed.dart';

import 'home_state.dart';

class HomeLogic extends GetxController with GetTickerProviderStateMixin {
  final HomeState state = HomeState();

  //fab动画控制器
  late AnimationController fabAnimationController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200));

  //fab动画插值器
  late Animation<double> fabAnimation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: fabAnimationController, curve: Curves.easeInOut));

  //bar动画控制器
  late AnimationController barAnimationController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200));

  //动画插值器
  late Animation<double> barAnimation = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: barAnimationController, curve: Curves.easeInOut));

  late PageController pageController = PageController();

  late final DiaryLogic diaryLogic = Bind.find<DiaryLogic>();
  late final FrostedGlassOverlayLogic frostedGlassOverlayLogic =
      Bind.find<FrostedGlassOverlayLogic>();

  late final AppLifecycleListener appLifecycleListener;

  @override
  void onReady() {
    //unawaited(Utils().updateUtil.checkShouldUpdate(PrefUtil.getValue<String>('appVersion')!.split('+')[0]));
    // unawaited(getHitokoto());
    // Tutorial.getTutorial(targets: buildFabGuide())
    //     .show(context: Get.overlayContext!);
    appLifecycleListener = AppLifecycleListener(onStateChange: (state) {
      if (state == AppLifecycleState.inactive) {
        privacyMode(isEnable: true);
        lockPage();
      }
      if (state == AppLifecycleState.resumed) {
        privacyMode(isEnable: false);
      }
    });

    super.onReady();
  }

  @override
  void onClose() {
    fabAnimationController.dispose();
    barAnimationController.dispose();
    pageController.dispose();
    super.onClose();
  }

  // List<TargetFocus> buildFabGuide() {
  //   return [
  //     TargetFocus(
  //       identify: 'fab',
  //       keyTarget: state.fabKey,
  //       contents: [
  //         Tutorial.buildTargetContent(
  //           title: '点击这里新建日记',
  //           align: ContentAlign.top,
  //         ),
  //       ],
  //       shape: ShapeLightFocus.RRect,
  //       radius: 20,
  //     ),
  //   ];
  // }

  //打开fab
  Future<void> openFab() async {
    await HapticFeedback.vibrate();
    state.isFabExpanded = true;
    update(['Fab']);
    await fabAnimationController.forward();
  }

  //关闭fab
  Future<void> closeFab() async {
    await HapticFeedback.selectionClick();
    await fabAnimationController.reverse();
    state.isFabExpanded = false;
    update(['Fab']);
  }

  //锁定屏幕
  void lockPage() {
    //如果开启密码的同时开启了立即锁定，就直接跳转到锁屏页面
    if (PrefUtil.getValue<bool>('lock') == true &&
        PrefUtil.getValue<bool>('lockNow') == true) {
      // 如果当前不在编辑，分享页面
      if (Get.currentRoute != AppRoutes.editPage &&
          Get.currentRoute != AppRoutes.sharePage) {
        Get.toNamed(AppRoutes.lockPage, arguments: 'pause');
      }
    }
  }

  //隐私模式
  void privacyMode({required bool isEnable}) {
    if (PrefUtil.getValue<bool>('backendPrivacy') == true) {
      isEnable
          ? frostedGlassOverlayLogic.enable()
          : frostedGlassOverlayLogic.disable();
    }
  }

  void toUserPage() {
    //如果已经登录
    if (SupabaseUtil().user != null || SupabaseUtil().session != null) {
      Get.toNamed(AppRoutes.userPage);
    } else {
      Get.toNamed(AppRoutes.loginPage);
    }
  }

  //新增一篇日记
  Future<void> toEditPage({required DiaryType type}) async {
    //同时关闭fab
    HapticFeedback.selectionClick();
    // 获取当前的分类id
    String? categoryId;
    if (diaryLogic.tabController.index == 0) {
      categoryId = null;
    } else {
      categoryId =
          diaryLogic.state.categoryList[diaryLogic.tabController.index - 1].id;
    }

    /// 需要注意，返回值为 '' 时才是没有选择分类，而返回值为 null 时，是没有进行操作直接返回
    var res =
        await Get.toNamed(AppRoutes.editPage, arguments: [type, categoryId]);
    fabAnimationController.reset();
    state.isFabExpanded = false;
    update(['Fab']);
    if (res != null) {
      if (res == '') {
        await diaryLogic.updateDiary(null);
      } else {
        await diaryLogic.updateDiary(res);
      }
    }
  }

  Future<void> hideNavigatorBar() async {
    await barAnimationController.forward();
  }

  Future<void> showNavigatorBar() async {
    await barAnimationController.reverse();
  }

  void resetNavigatorBar() {
    barAnimationController.reset();
  }

  // 切换导航栏
  void changeNavigator(int index) {
    state.navigatorIndex = index;
    update(['NavigatorBar', 'Fab', 'Layout']);
    pageController.jumpToPage(index);
  }
}
