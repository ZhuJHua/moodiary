import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/components/diary_tab_view/diary_tab_view_logic.dart';
import 'package:mood_diary/utils/utils.dart';

import 'diary_state.dart';

class DiaryLogic extends GetxController with GetSingleTickerProviderStateMixin {
  final DiaryState state = DiaryState();

  late TabController tabController;

  late PageController pageController = PageController();

  @override
  void onInit() async {
    // TODO: implement onInit
    await initCategoryTab();
    super.onInit();
  }

  @override
  void onReady() {
    // TODO: implement onReady

    state.innerController.addListener(() async {
      if (!tabController.indexIsChanging) {
        double offset = state.innerController.offset;
        double maxScrollExtent = state.innerController.position.maxScrollExtent;

        // 显示或隐藏“回到顶部”按钮
        state.isToTopShow.value = offset > 0;
        // 分页加载
        if (offset == maxScrollExtent) {
          await pagination();
        }
      }
    });
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    tabController.dispose();
    pageController.dispose();

    super.onClose();
  }

  //更新tabview位置
  void updateTabViewIndex(int value) {
    state.tabViewIndex.value = value;
  }

  Future<void> pagination() async {
    DiaryTabViewLogic homeTabViewLogic = Bind.find<DiaryTabViewLogic>(tag: tabController.index.toString());
    await homeTabViewLogic.paginationDiary(homeTabViewLogic.state.diaryList.length);
  }

  //初始化分类tab
  Future<void> initCategoryTab() async {
    //从数据库获取分类
    state.categoryList.value = await Utils().isarUtil.getAllCategoryAsync();
    //初始化tab控制器，长度加一由于有一个默认分类
    tabController = TabController(length: state.categoryList.length + 1, vsync: this);
    state.isFetching.value = false;
  }

  //重新获取当前页日历
  Future<void> updateDiary() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      DiaryTabViewLogic homeTabViewLogic = Bind.find<DiaryTabViewLogic>(tag: state.tabViewIndex.value.toString());
      await homeTabViewLogic.getDiary();
    });
  }

  //重新获取分类
  Future<void> updateCategory() async {
    state.isFetching.value = true;
    //重新获取分类
    state.categoryList.value = await Utils().isarUtil.getAllCategoryAsync();
    //重新初始化Tab控制器
    var currentIndex = tabController.index;
    //如果删除了最后一个，就往左移
    if (state.categoryList.length < currentIndex) {
      currentIndex = state.categoryList.length;
    }
    //删除原有控制器
    tabController.dispose();
    //重新创建控制器
    tabController = TabController(length: state.categoryList.length + 1, vsync: this, initialIndex: currentIndex);
    state.isFetching.value = false;
  }

  //切换视图模式
  Future<void> changeViewMode(ViewModeType viewModeType) async {
    state.viewModeType.value = viewModeType;
    await Utils().prefUtil.setValue<int>('homeViewMode', viewModeType.number);
  }

  Future<void> toTop() async {
    await state.innerController.animateTo(0.0, duration: const Duration(milliseconds: 100), curve: Curves.easeInOut);
    await state.outerController.animateTo(0.0, duration: const Duration(milliseconds: 100), curve: Curves.easeInOut);
  }
}
