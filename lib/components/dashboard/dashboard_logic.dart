import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';

import 'dashboard_state.dart';

class DashboardLogic extends GetxController {
  final DashboardState state = DashboardState();

  @override
  void onReady() async {
    getUseTime();
    getDiaryCount();
    //unawaited(getMoodAndWeatherByRange(state.dateRange[0], state.dateRange[1]));
    unawaited(getCountContent());
    getCategoryCount();
    super.onReady();
  }

  Future<void> getCountContent() async {
    var list = await Utils().isarUtil.getContentList();
    int count = await compute(Utils().arrayUtil.countListItemLength, list);
    state.contentCount.value = count.toString();
  }

  void getDiaryCount() {
    int count = Utils().isarUtil.countAllDiary();
    state.diaryCount.value = count.toString();
  }

  void getCategoryCount() {
    int count = Utils().isarUtil.countCategories();
    state.categoryCount.value = count.toString();
  }

  //选中两个日期后，查询指定范围内的日记
  Future<void> getMoodAndWeatherByRange(DateTime start, DateTime end) async {
    var moodList = await Utils().isarUtil.getMoodByDateRange(start, end.subtract(const Duration(days: -1)));
    var weatherList = await Utils().isarUtil.getWeatherByDateRange(start, end.subtract(const Duration(days: -1)));

    //去掉没有天气
    weatherList.removeWhere((item) => item.isEmpty);
    if (moodList.isNotEmpty) {
      state.recentMood.value =
          Utils().arrayUtil.countList(moodList).entries.reduce((a, b) => a.value > b.value ? a : b).key.toString();
    } else {
      state.recentMood.value = 'none';
    }
    if (weatherList.isNotEmpty) {
      var weatherCode = List.generate(weatherList.length, (index) => weatherList[index].first);
      state.recentWeather.value =
          Utils().arrayUtil.countList(weatherCode).entries.reduce((a, b) => a.value > b.value ? a : b).key;
    } else {
      state.recentWeather.value = 'none';
    }
  }

  void getUseTime() {
    DateTime firstStart = DateTime.fromMillisecondsSinceEpoch(Utils().prefUtil.getValue<int>('startTime')!);
    Duration duration = DateTime.now().difference(firstStart);
    state.useTime.value = (duration.inDays + 1).toString();
  }

  Future<void> toDiaryManager() async {
    Get.toNamed(AppRoutes.diaryManagerPage);
  }
}
