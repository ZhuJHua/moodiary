import 'dart:convert';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/api/api.dart';
import 'package:mood_diary/common/models/hunyuan.dart';
import 'package:mood_diary/utils/utils.dart';

import 'analyse_state.dart';

class AnalyseLogic extends GetxController {
  final AnalyseState state = AnalyseState();

  @override
  void onReady() {
    // TODO: implement onReady

    super.onReady();
  }

  @override
  void onInit() {
    // TODO: implement onInit
    getMoodAndWeatherByRange(state.dateRange[0], state.dateRange[1]);
    super.onInit();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  //选中两个日期后，查询指定范围内的日记
  Future<void> getMoodAndWeatherByRange(DateTime start, DateTime end) async {
    //清空原有数据
    clearResult();
    //获取数据开始
    state.finished = false;
    update();
    state.moodList = await Utils().isarUtil.getMoodByDateRange(start, end.subtract(const Duration(days: -1)));
    var weatherList = await Utils().isarUtil.getWeatherByDateRange(start, end.subtract(const Duration(days: -1)));
    Utils().logUtil.printInfo(weatherList);
    for (var weather in weatherList) {
      if (weather.isNotEmpty) {
        state.weatherList.add(weather.first);
      }
    }
    state.moodMap = Utils().arrayUtil.countList(state.moodList);
    state.weatherMap = Utils().arrayUtil.countList(state.weatherList);
    state.finished = true;
    update();
  }

  void clearResult() {
    state.moodList.clear();
    state.weatherList.clear();
    state.moodMap.clear();
    state.weatherMap.clear();
  }

  //弹出日期选择框
  Future<void> openDatePicker(context) async {
    var result = await showCalendarDatePicker2Dialog(
        context: context,
        config: CalendarDatePicker2WithActionButtonsConfig(
          calendarViewMode: CalendarDatePicker2Mode.day,
          calendarType: CalendarDatePicker2Type.range,
          selectableDayPredicate: (date) => date.isBefore(DateTime.now()),
        ),
        dialogSize: const Size(325, 400),
        value: state.dateRange,
        borderRadius: BorderRadius.circular(20.0));
    if (result != null) {
      state.dateRange[0] = result[0]!;
      state.dateRange[1] = result[1]!;
      update();
      getMoodAndWeatherByRange(result[0]!, result[1]!);
    }
  }

  Future<void> getAi() async {
    var check = Utils().signatureUtil.checkTencent();
    if (check != null) {
      state.reply = '';
      update();
      var stream = await Api().getHunYuan(
          check['id']!,
          check['key']!,
          [
            Message('system',
                '我会给你一组来自一款日记APP的数据，其中包含了在某一段时间内，日记所记录的心情和天气情况，根据这些数据，给出我一条建议用户如何改善心情，回答稍微带一点文艺感，总字数不要超过200字，不需要任何其他反馈。'),
            Message('user', '心情：${state.moodMap.toString()}，天气：${state.weatherMap.toString()}')
          ],
          0);
      stream?.listen((content) {
        if (content != '' && content.contains('data')) {
          HunyuanResponse result = HunyuanResponse.fromJson(jsonDecode(content.split('data: ')[1]));
          state.reply += result.choices!.first.delta!.content!;
          update();
        }
      });
    }
  }
}
