class AnalyseState {
  //当前选中的日期范围，默认为今天起一周
  late List<DateTime> dateRange;

  //统计范围内的心情列表
  late List<double> moodList;

  //天气
  late List<String> weatherList;

  //统计范围内日记的心情出现的次数
  late Map<double, int> moodMap;

  late Map<String, int> weatherMap;

  //加载状态，检查数据是否获取完成
  late bool finished;

  late String reply;

  AnalyseState() {
    var now = DateTime.now().copyWith(hour: 0, minute: 0, second: 0);
    reply = '';
    finished = false;
    dateRange = [now.subtract(const Duration(days: 30)), now];
    moodList = [];
    weatherList = [];
    moodMap = {};
    weatherMap = {};
  }
}
