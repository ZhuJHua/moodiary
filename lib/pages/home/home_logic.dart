import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/components/home_tab_view/home_tab_view_logic.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';

import 'home_state.dart';

class HomeLogic extends GetxController with GetTickerProviderStateMixin {
  final HomeState state = HomeState();

  //fab动画控制器
  late AnimationController fabAnimationController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

  //fab动画插值器
  late Animation<double> fabAnimation =
      Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: fabAnimationController, curve: Curves.easeInOut));

  //tab控制器，默认全部分类，长度加一
  late TabController tabController = TabController(length: state.categoryList.length + 1, vsync: this);

  Set<double> maxScrollExtentSet = {};

  @override
  void onInit() {
    // TODO: implement onInit

    super.onInit();
  }

  @override
  void onReady() {
    // TODO: implement onReady

    var innerController = state.nestedScrollKey.currentState!.innerController;

    innerController.addListener(() async {
      if (!tabController.indexIsChanging) {
        double offset = innerController.offset;
        double maxScrollExtent = innerController.position.maxScrollExtent;
        // 显示或隐藏“回到顶部”按钮
        state.isToTopShow.value = offset > 0;
        // 分页加载
        if (offset == maxScrollExtent && !maxScrollExtentSet.contains(offset)) {
          maxScrollExtentSet.add(offset);
          HomeTabViewLogic homeTabViewLogic = Bind.find<HomeTabViewLogic>(tag: tabController.index.toString());
          await homeTabViewLogic.paginationDiary(homeTabViewLogic.state.diaryList.length, 10);
        }
      }
    });

    initTabListener();
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    fabAnimationController.dispose();
    tabController.dispose();
    super.onClose();
  }

  void initTabListener() {
    //监听tab滚动，切换时回到顶部

    tabController.addListener(() async {
      if (!tabController.indexIsChanging) {
        var outerController = state.nestedScrollKey.currentState!.outerController;
        if (outerController.offset != .0) {
          await outerController.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
          //标记为变化结束
        }
      }
    });
  }

  Future<void> toTop() async {
    var outerController = state.nestedScrollKey.currentState!.outerController;
    await outerController.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
  }

  //初始化分类tab
  Future<void> initCategoryTab() async {
    //从数据库获取分类
    state.categoryList.value = await Utils().isarUtil.getAllCategoryAsync();
    //初始化tab控制器，长度加一由于有一个默认分类
    tabController = TabController(length: state.categoryList.length + 1, vsync: this);
  }

  //重新获取当前页日历
  Future<void> updateDiary() async {
    //重新获取分类
    state.categoryList.value = await Utils().isarUtil.getAllCategoryAsync();
    //重新初始化Tab控制器
    var currentIndex = tabController.index;
    //如果删除了最后一个，就往左移
    if (state.categoryList.length < currentIndex) {
      currentIndex = state.categoryList.length;
    }
    //移出原有监听器
    tabController.removeListener(initTabListener);
    tabController = TabController(length: state.categoryList.length + 1, vsync: this, initialIndex: currentIndex);
    //重新开始监听
    initTabListener();
    maxScrollExtentSet = {};
    //添加帧回调保证对应logic已经被创建
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      HomeTabViewLogic homeTabViewLogic = Bind.find<HomeTabViewLogic>(tag: currentIndex.toString());
      await homeTabViewLogic.getDiary();
    });
  }

  //打开fab
  Future<void> openFab() async {
    await HapticFeedback.selectionClick();
    state.isFabExpanded.value = true;
    //开始动画
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

  //切换视图模式
  Future<void> changeViewMode(ViewMode viewMode) async {
    state.viewMode.value = viewMode.name;
    await Utils().prefUtil.setValue<String>('homeViewMode', viewMode.name);
  }

  //新增一篇日记
  Future<void> toEditPage() async {
    //同时关闭fab
    await HapticFeedback.selectionClick();
    //等待跳转，返回后刷新
    await Get.toNamed(AppRoutes.editPage, arguments: 'new');
    fabAnimationController.reset();
    state.isFabExpanded.value = false;
    await updateDiary();
    //点击添加按钮后新增一篇日记
  }
}
