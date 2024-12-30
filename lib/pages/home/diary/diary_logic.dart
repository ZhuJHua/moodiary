import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/components/diary_tab_view/diary_tab_view_logic.dart';
import 'package:mood_diary/components/scroll/fix_scroll.dart';
import 'package:mood_diary/pages/home/home_logic.dart';

import '../../../utils/data/isar.dart';
import '../../../utils/data/pref.dart';
import '../../../utils/webdav_util.dart';
import 'diary_state.dart';

class DiaryLogic extends GetxController with GetTickerProviderStateMixin {
  final DiaryState state = DiaryState();

  //初始化tab控制器，长度加一由于有一个默认分类
  late TabController tabController =
      TabController(length: state.categoryList.length + 1, vsync: this);

  late HomeLogic homeLogic = Bind.find<HomeLogic>();

  double lastScrollOffset = .0;

  @override
  void onInit() {
    autoSync();
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

  Future<void> autoSync() async {
    if (PrefUtil.getValue<bool>('autoSync') == true &&
        await WebDavUtil().checkConnectivity()) {
      var diary = await IsarUtil.getAllDiaries();
      await WebDavUtil().syncDiary(diary, onDownload: () async {
        await refreshAll();
      });
    }
  }

  /// tab 监听函数
  /// 在动态更新分类后要重新监听
  void _tabBarListener() {
    if (tabController.indexIsChanging) return;
    checkPageChange();
    // 检查是否显示顶部内容
    _checkShowTop();
    homeLogic.resetNavigatorBar();
  }

  /// inner controller 监听函数
  /// 用于分页
  void _innerControllerListener() async {
    double offset = state.innerController.offset;
    double maxScrollExtent = state.innerController.position.maxScrollExtent;
    _checkShowTop();
    if (offset - lastScrollOffset > 100) {
      lastScrollOffset = offset;
      await homeLogic.hideNavigatorBar();
    }
    if (lastScrollOffset - offset > 100) {
      lastScrollOffset = offset;
      await homeLogic.showNavigatorBar();
    }
    if (offset == maxScrollExtent) {
      if (tabController.index == 0) {
        await Bind.find<DiaryTabViewLogic>(tag: 'default').paginationDiary();
      } else {
        await Bind.find<DiaryTabViewLogic>(
                tag: state.categoryList[tabController.index - 1].id)
            .paginationDiary();
      }
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
    if (state.innerController.hasClients) {
      if (homeLogic.state.isToTopShow != state.innerController.offset > 100) {
        homeLogic.state.isToTopShow = state.innerController.offset > 100;
        homeLogic.update(['Fab']);
      }
    } else {
      homeLogic.state.isToTopShow = false;
      homeLogic.update(['Fab']);
    }
  }

  /// 自定义 PrimaryController 的修改
  /// 需要在以下情况调用
  /// 1. tab bar 修改
  /// 2. update ho
  void checkPageChange() {
    state.currentTabBarIndex = tabController.index;
    // 获取当前分类ID，若为默认分类，设为 'default'
    String categoryId = state.currentTabBarIndex == 0
        ? 'default'
        : state.categoryList[state.currentTabBarIndex - 1].id;
    // 遍历 keyMap，更新每个分类的状态
    state.keyMap.forEach((k, v) {
      v.currentState?.onPageChange(k == categoryId);
    });
  }

  /// 日记刷新函数
  /// 需要在以下情况调用
  ///
  /// 1. 新增日记之后
  /// 2. 回收站恢复日记之后
  /// 3. 编辑时修改了分类
  Future<void> updateDiary(String? categoryId, {bool jump = true}) async {
    //如果分类为空，说明没有分类，跳转到全部分类
    int tabViewIndex;
    if (categoryId == null) {
      tabViewIndex = 0;
      if (jump && tabController.index != 0) {
        tabController.animateTo(0);
      }
    } else {
      //查找分类对应的位置，加一是因为默认分类占了一个
      tabViewIndex =
          state.categoryList.indexWhere((e) => e.id == categoryId) + 1;
      if (jump && tabController.index != 0) {
        tabController.animateTo(tabViewIndex);
      }
    }
    //如果控制器已经存在，重新获取，如果不存在，不需要任何操作
    if (tabViewIndex != 0 &&
        Bind.isRegistered<DiaryTabViewLogic>(tag: categoryId)) {
      await Bind.find<DiaryTabViewLogic>(tag: categoryId).updateDiary();
    }
    await Bind.find<DiaryTabViewLogic>(tag: 'default').updateDiary();
  }

  Future<void> refreshAll() async {
    await updateCategory();
    await updateDiary(null, jump: true);
    await Future.wait(
      state.categoryList.map(
        (category) => updateDiary(category.id, jump: false),
      ),
    );
  }

  /// 分类刷新函数
  /// 需要在以下情况调用
  ///
  /// 1. 新增分类之后
  /// 2. 修改分类之后
  /// 3. 删除分类之后
  Future<void> updateCategory() async {
    //重新获取分类
    state.categoryList = await IsarUtil.getAllCategoryAsync();

    // 移除 Map 中不再存在的 Category id
    state.keyMap.removeWhere((k, v) =>
        !state.categoryList.map((category) => category.id).contains(k) &&
        k != 'default');

    // 为新的 Category 添加新的 GlobalKey
    for (var category in state.categoryList) {
      if (!state.keyMap.containsKey(category.id)) {
        state.keyMap[category.id] = GlobalKey<PrimaryScrollWrapperState>();
      }
    }
    //重新初始化Tab控制器
    state.currentTabBarIndex = tabController.index;
    //如果删除了最后一个，就往左移
    if (state.categoryList.length < state.currentTabBarIndex) {
      state.currentTabBarIndex = state.categoryList.length;
    }

    //重新创建控制器
    tabController.removeListener(_tabBarListener);
    tabController = TabController(
        length: state.categoryList.length + 1,
        vsync: this,
        initialIndex: state.currentTabBarIndex);
    tabController.addListener(_tabBarListener);
    update(['All']);
    checkPageChange();
  }

  //切换视图模式
  Future<void> changeViewMode(ViewModeType viewModeType) async {
    state.viewModeType = viewModeType;
    update(['TabBarView']);
    _checkShowTop();
    await PrefUtil.setValue<int>('homeViewMode', viewModeType.number);
  }

  // 回到顶部函数
  Future<void> toTop() async {
    await state.innerController.animateTo(0.0,
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
  }

  // 更新标题
  void updateTitle() {
    state.customTitleName = PrefUtil.getValue<String>('customTitleName')!;
    update(['Title']);
  }
}
