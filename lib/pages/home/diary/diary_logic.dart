import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/components/diary_tab_view/diary_tab_view_logic.dart';
import 'package:mood_diary/utils/utils.dart';

import 'diary_state.dart';

class DiaryLogic extends GetxController with GetTickerProviderStateMixin {
  final DiaryState state = DiaryState();

  //初始化tab控制器，长度加一由于有一个默认分类
  late TabController tabController = TabController(length: state.categoryList.length + 1, vsync: this);

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onReady() {
    //监听 tab
    tabController.addListener(_tabBarListener);
    //监听 inner
    state.innerController.addListener(_innerControllerListener);
    super.onReady();
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  /// tab 监听函数
  /// 在动态更新分类后要重新监听？
  void _tabBarListener() {
    if (!tabController.indexIsChanging) {
      state.currentTabBarIndex = tabController.index;
      for (var key in state.keyList) {
        key.currentState?.onPageChange(state.currentTabBarIndex == state.keyList.indexOf(key));
      }
      _checkShowTop();
    }
  }

  /// inner controller 监听函数
  /// 用于分页
  void _innerControllerListener() async {
    double offset = state.innerController.offset;
    double maxScrollExtent = state.innerController.position.maxScrollExtent;
    _checkShowTop();
    if (offset == maxScrollExtent) {
      await Bind.find<DiaryTabViewLogic>(tag: tabController.index.toString()).paginationDiary();
    }
  }

  /// 检查回到顶部函数
  /// 通过检测inner controller实现
  /// 需要注意的是，可能需要随时手动刷新
  ///
  /// 以下时候需要调用
  /// 1. 在inner中滑动时
  /// 2. tab切换时
  /// 3. view mode刷新时（实际上肯定在顶部，干脆直接改state）
  void _checkShowTop() {
    state.isToTopShow.value = state.innerController.offset > 100;
  }

  /// 日记刷新函数
  /// 需要在以下情况调用
  ///
  /// 1. 新增日记之后
  /// 2. 回收站恢复日记之后
  /// 3. 编辑时修改了分类
  Future<void> updateDiary(String? categoryId) async {
    //如果分类为空，说明没有分类，跳转到全部分类
    int tabViewIndex;
    if (categoryId == null) {
      tabViewIndex = 0;
      tabController.animateTo(0);
    } else {
      //查找分类对应的位置，加一是因为默认分类占了一个
      tabViewIndex = state.categoryList.indexWhere((e) => e.id == categoryId) + 1;
      tabController.animateTo(tabViewIndex);
    }
    //如果控制器已经存在，重新获取，如果不存在，不需要任何操作
    if (tabViewIndex != 0 && Bind.isRegistered<DiaryTabViewLogic>(tag: tabViewIndex.toString())) {
      await Bind.find<DiaryTabViewLogic>(tag: tabViewIndex.toString()).getDiary();
    }
    await Bind.find<DiaryTabViewLogic>(tag: '0').getDiary();
  }

  /// 分类刷新函数
  /// 需要在以下情况调用
  ///
  /// 1. 新增分类之后
  /// 2. 修改分类之后
  /// 3. 删除分类之后
  Future<void> updateCategory() async {
    //重新获取分类
    state.categoryList = await Utils().isarUtil.getAllCategoryAsync();

    //重新获取key
    state.keyList = List.generate(state.categoryList.length + 1, (index) {
      return GlobalKey();
    });
    //重新初始化Tab控制器
    var currentIndex = tabController.index;
    //如果删除了最后一个，就往左移
    if (state.categoryList.length < currentIndex) {
      currentIndex = state.categoryList.length;
    }

    //重新创建控制器
    tabController = TabController(length: state.categoryList.length + 1, vsync: this, initialIndex: currentIndex);

    tabController.addListener(() {
      if (!tabController.indexIsChanging) {
        state.currentTabBarIndex = tabController.index;
        for (var key in state.keyList) {
          key.currentState?.onPageChange(state.currentTabBarIndex == state.keyList.indexOf(key));
        }
        double offset = state.innerController.offset;

        state.isToTopShow.value = offset > 100;
      }
    });
    //刷新
    update();
  }

  //切换视图模式
  Future<void> changeViewMode(ViewModeType viewModeType) async {
    state.viewModeType.value = viewModeType;
    state.isToTopShow.value = false;
    await Utils().prefUtil.setValue<int>('homeViewMode', viewModeType.number);
  }

  // 回到顶部函数
  Future<void> toTop() async {
    await state.innerController.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.linear);
  }
}
