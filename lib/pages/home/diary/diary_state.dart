import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/category.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/components/scroll/fix_scroll.dart';
import 'package:mood_diary/utils/utils.dart';

class DiaryState {
  //自定义标题名称，如果为空则为默认值
  late String customTitleName;

  //分类列表，用于tab显示
  late List<Category> categoryList;

  //主滚动列表key
  late GlobalKey<NestedScrollViewState> nestedScrollKey;

  ScrollController get innerController => nestedScrollKey.currentState!.innerController;

  ScrollController get outerController => nestedScrollKey.currentState!.outerController;

  //视图模式状态
  late Rx<ViewModeType> viewModeType;

  //回到顶部状态
  late RxBool isToTopShow;

  //当前tab bar位置
  late int currentTabBarIndex;

  late List<GlobalKey<PrimaryScrollWrapperState>> keyList;

  DiaryState() {
    customTitleName = Utils().prefUtil.getValue<String>('customTitleName')!;

    nestedScrollKey = GlobalKey<NestedScrollViewState>();

    viewModeType = ViewModeType.getType(Utils().prefUtil.getValue<int>('homeViewMode')!).obs;

    currentTabBarIndex = 0;

    //第一次获取分类，这里是同步方法，因为分类数量是可控的，所以应该不会有性能问题，但愿如此
    categoryList = Utils().isarUtil.getAllCategory();

    keyList = List.generate(categoryList.length + 1, (index) {
      return GlobalKey();
    });

    isToTopShow = false.obs;

    ///Initialize variables
  }
}
