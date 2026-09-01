import 'package:moodiary_diary/src/application/diary_stamp.dart';
import 'package:moodiary_models/moodiary_models.dart';

export 'package:moodiary_diary/src/application/diary_stamp.dart'
    show diaryStampOf;

/// 时间线上的一条日记。轴的每一段视觉（日期头、圆点、断档虚线）都由这里的标志位决定，
/// 渲染层不再自己回溯前后条目。
class TimelineEntry {
  final Diary diary;

  /// 参与分组与展示的时间戳（**本地时区**）。按「最近修改」排序时它是 lastModified，
  /// 否则是 time —— 分组键必须等于排序键，否则月份吸顶头会重复且乱序。
  final DateTime stamp;

  /// 是否为所在自然日的第一条 —— 只有它在左栏画日期。
  final bool dayStart;

  /// 与上一条之间空了至少一整天（相邻日不算）。轴在此处转虚线并留白。
  final bool breakBefore;

  const TimelineEntry({
    required this.diary,
    required this.stamp,
    required this.dayStart,
    required this.breakBefore,
  });
}

/// 时间线的一个月份分组。
class TimelineMonth {
  /// 该月 1 号零点（本地时区），供吸顶头格式化。
  final DateTime month;
  final List<TimelineEntry> entries;

  const TimelineMonth({required this.month, required this.entries});
}

/// 把**已加载的前缀**切成「月 → 条目」两级。纯函数：同样的输入永远得到同样的输出，
/// 分页续加、同步回写触发的整表重排都只是重新调用一次。
///
/// [diaries] 必须已按 [sort] 排好序（controller 保证）。跨分页边界的同一天会自然并入
/// 同一天（只看相邻两条的日期差），因此最后一组可能是不完整的一天 —— 调用方据此决定
/// 要不要画收尾。
List<TimelineMonth> buildTimeline(List<Diary> diaries, DiarySort sort) {
  final months = <TimelineMonth>[];
  var entries = <TimelineEntry>[];
  DateTime? currentMonth;
  DateTime? prevDay;

  for (final diary in diaries) {
    final stamp = diaryStampOf(diary, sort);
    // 日键刻意用 UTC 构造：只拿它算「差了几个日历日」。若用本地零点，跨夏令时前拨的
    // 两天只差 47 小时，Duration.inDays 会截断成 1，整整空一天的断档就漏判了。
    // 月份仍按本地取，吸顶头显示的是用户所在时区的月份。
    final day = DateTime.utc(stamp.year, stamp.month, stamp.day);
    final month = DateTime(stamp.year, stamp.month);

    if (currentMonth == null || month != currentMonth) {
      if (currentMonth != null) {
        months.add(TimelineMonth(month: currentMonth, entries: entries));
        entries = <TimelineEntry>[];
      }
      currentMonth = month;
    }

    entries.add(
      TimelineEntry(
        diary: diary,
        stamp: stamp,
        dayStart: prevDay == null || day != prevDay,
        // 只看「差了几天」而不看方向：升序排列时同样成立。
        breakBefore:
            prevDay != null && day.difference(prevDay).inDays.abs() > 1,
      ),
    );
    prevDay = day;
  }

  if (currentMonth != null) {
    months.add(TimelineMonth(month: currentMonth, entries: entries));
  }
  return months;
}
