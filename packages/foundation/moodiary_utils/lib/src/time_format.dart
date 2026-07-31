import 'package:intl/intl.dart';

/// 统一的时间展示工具。入参为绝对时刻（UTC 或本地皆可），内部一律先
/// `toLocal()` 再格式化；本地化跟随启动/切语言时设置的 `Intl.defaultLocale`。
class TimeFormat {
  /// 播放时长：m:ss，超过 1 小时给 h:mm:ss（分钟此时补零）。负数按 0。
  /// 与编辑器 webview 内 use-media.ts 的 formatTime 保持一致，两端观感统一。
  static String mediaDuration(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '$m:$ss';
  }

  /// 「已播 / 总长」。总长未知（<= 0）时只给已播 —— Android 对无 moov 的残缺 mp4
  /// 会报 DURATION_UNSET，此时画一个假的总长比不画更糟。
  static String mediaPosition(Duration position, Duration duration) =>
      duration <= Duration.zero
      ? mediaDuration(position)
      : '${mediaDuration(position)} / ${mediaDuration(duration)}';

  /// 完整日期+星期+时分秒——详情页等需要完整精度的场景。
  static String fullDateTime(DateTime time) =>
      DateFormat.yMMMMEEEEd().add_Hms().format(time.toLocal());

  /// 完整日期+星期——分组标题、分享卡片等强调日期的场景。
  static String fullDate(DateTime time) =>
      DateFormat.yMMMMEEEEd().format(time.toLocal());

  /// 长日期+时分——分享文本/卡片。
  static String longDateTime(DateTime time) =>
      DateFormat.yMMMMd().add_Hm().format(time.toLocal());

  /// 长日期——备链等用日期替代无标题日记的场景。
  static String longDate(DateTime time) =>
      DateFormat.yMMMMd().format(time.toLocal());

  /// 紧凑日期+时分——列表行副标题（回收站/管理/上次同步）。
  static String listDateTime(DateTime time) =>
      DateFormat.yMd().add_Hm().format(time.toLocal());

  /// 无年份短日期+星期——首页卡片。
  static String cardDate(DateTime time) =>
      DateFormat.MMMEd().format(time.toLocal());

  /// 带年份紧凑日期——搜索结果等空间受限但需要年份的场景。
  static String mediumDate(DateTime time) =>
      DateFormat.yMMMd().format(time.toLocal());

  /// 固定 `yyyy-MM-dd`——机器可读、不随语言变化：LLM 工具输出、wikilink
  /// 候选、日志日期标签。
  static String isoDate(DateTime time) {
    final t = time.toLocal();
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '${t.year}-$m-$d';
  }

  /// 时分秒——同步日志等只看时刻的场景。
  static String timeHms(DateTime time) =>
      DateFormat.Hms().format(time.toLocal());

  /// 时分——时间线条目只需要「几点几分」，日期由左侧轴上的节点承担。
  static String clock(DateTime time) => DateFormat.Hm().format(time.toLocal());

  /// 年月——时间线的月份吸顶头。
  static String monthTitle(DateTime time) =>
      DateFormat.yMMMM().format(time.toLocal());

  /// 短星期（周一 / Mon）——时间线左栏日期下的第二行。
  static String weekdayShort(DateTime time) =>
      DateFormat.E().format(time.toLocal());

  /// 相对时间——今天给时分，今年给月日，更早给年月日（会话列表）。
  static String relative(DateTime time) {
    final t = time.toLocal();
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return DateFormat.Hm().format(t);
    }
    if (t.year == now.year) return DateFormat.MMMd().format(t);
    return DateFormat.yMMMd().format(t);
  }
}
