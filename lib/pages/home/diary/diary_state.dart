import 'package:flutter/material.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/common/values/view_mode.dart';
import 'package:moodiary/components/scroll/fix_scroll.dart';
import 'package:moodiary/presentation/isar.dart';
import 'package:moodiary/presentation/pref.dart';
import 'package:refreshed/refreshed.dart';

class DiaryState {
  //自定义标题名称，如果为空则为默认值
  late RxString customTitleName;

  //分类列表，用于tab显示
  late List<Category> categoryList;

  //分类列表对应的key map，key是列表id
  late Map<String, GlobalKey<PrimaryScrollWrapperState>> keyMap;

  //主滚动列表key
  late GlobalKey<NestedScrollViewState> nestedScrollKey;

  ScrollController get innerController =>
      nestedScrollKey.currentState!.innerController;

  ScrollController get outerController =>
      nestedScrollKey.currentState!.outerController;

  //视图模式状态
  late Rx<ViewModeType> viewModeType =
      ViewModeType.getType(PrefUtil.getValue<int>('homeViewMode')!).obs;

  //当前tab bar位置
  late int currentTabBarIndex;

  // 一言
  RxString hitokoto = '...'.obs;

  DiaryState() {
    customTitleName = PrefUtil.getValue<String>('customTitleName')!.obs;

    nestedScrollKey = GlobalKey<NestedScrollViewState>();

    currentTabBarIndex = 0;

    //第一次获取分类，这里是同步方法，因为分类数量是可控的，所以应该不会有性能问题，但愿如此
    categoryList = IsarUtil.getAllCategory();

    //默认分类
    keyMap = {'default': GlobalKey<PrimaryScrollWrapperState>()};
    //其他分类
    for (var category in categoryList) {
      keyMap[category.id] = GlobalKey<PrimaryScrollWrapperState>();
    }
  }
}
