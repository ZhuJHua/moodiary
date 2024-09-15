import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/category.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/utils/utils.dart';

class DiaryState {
  //自定义标题名称，如果为空则为默认值
  late String customTitleName;

  //分类列表，用于tab显示
  late RxList<Category> categoryList;

  late RxBool isFetching;

  //当前tabview位置
  late RxInt tabViewIndex;

  //主滚动列表key
  late GlobalKey<NestedScrollViewState> nestedScrollKey;

  ScrollController get innerController => nestedScrollKey.currentState!.innerController;

  ScrollController get outerController => nestedScrollKey.currentState!.outerController;

  //视图模式状态
  late Rx<ViewModeType> viewModeType;

  //回到顶部状态
  late RxBool isToTopShow;

  DiaryState() {
    isFetching = true.obs;
    customTitleName = Utils().prefUtil.getValue<String>('customTitleName')!;

    nestedScrollKey = GlobalKey<NestedScrollViewState>();

    viewModeType = ViewModeType.getType(Utils().prefUtil.getValue<int>('homeViewMode')!).obs;

    categoryList = <Category>[].obs;

    isToTopShow = false.obs;

    tabViewIndex = 0.obs;

    ///Initialize variables
  }
}
