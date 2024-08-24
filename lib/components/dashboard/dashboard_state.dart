import 'package:get/get.dart';

class DashboardState {
  //日记数量
  late RxString diaryCount;

  //日记文字总数
  late RxString contentCount;

  //使用时间
  late RxString useTime;

  //分类数量
  late RxString categoryCount;

  //分析近期的日期默认一周
  late List<DateTime> dateRange;
  late RxString recentMood;
  late RxString recentWeather;

  DashboardState() {
    var now = DateTime.now().copyWith(hour: 0, minute: 0, second: 0);
    dateRange = [now.subtract(const Duration(days: 6)), now];
    diaryCount = ''.obs;
    categoryCount = ''.obs;
    contentCount = ''.obs;
    recentMood = ''.obs;
    recentWeather = ''.obs;
    useTime = ''.obs;

    ///Initialize variables
  }
}
