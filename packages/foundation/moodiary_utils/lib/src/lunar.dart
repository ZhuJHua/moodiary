/// 农历换算（1900–2100），数据与算法为通行压缩表实现：
/// 每个年份一个 20bit 字段——低 4bit 闰月月份，中间 12bit 正月到腊月大小月，
/// 第 17bit 闰月大小（大月 30 天，小月 29 天）。
library;

class LunarDate {
  const LunarDate({
    required this.year,
    required this.month,
    required this.day,
    this.isLeapMonth = false,
  });

  /// 农历年（如 2026）
  final int year;

  /// 农历月（1–12）
  final int month;

  /// 农历日（1–30）
  final int day;

  /// 是否闰月
  final bool isLeapMonth;

  @override
  String toString() =>
      'LunarDate($year-$month-$day${isLeapMonth ? ' 闰' : ''})';
}

class LunarCalendar {
  LunarCalendar._();

  /// 1900-01-31 = 庚子年正月初一，换算基准
  static final DateTime _base = DateTime(1900, 1, 31);

  /// 1900–2100 农历数据表
  static const List<int> _info = [
    0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0,
    0x09ad0, 0x055d2, 0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540,
    0x0d6a0, 0x0ada2, 0x095b0, 0x14977, 0x04970, 0x0a4b0, 0x0b4b5, 0x06a50,
    0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970, 0x06566, 0x0d4a0,
    0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
    0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2,
    0x0a950, 0x0b557, 0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573,
    0x052b0, 0x0a9a8, 0x0e950, 0x06aa0, 0x0aea6, 0x0ab50, 0x04b60, 0x0aae4,
    0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0, 0x096d0, 0x04dd5,
    0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6,
    0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46,
    0x0ab60, 0x09570, 0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58,
    0x055c0, 0x0ab60, 0x096d5, 0x092e0, 0x0c960, 0x0d954, 0x0d4a0, 0x0da50,
    0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5, 0x0a950, 0x0b4a0,
    0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260,
    0x0ea65, 0x0d530, 0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0,
    0x1d0b6, 0x0d250, 0x0d520, 0x0dd45, 0x0b5a0, 0x056d0, 0x055b2, 0x049b0,
    0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0, 0x14b63, 0x09370,
    0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
    0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0,
    0x0a6d0, 0x055d4, 0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50,
    0x055a0, 0x0aba4, 0x0a5b0, 0x052b0, 0x0b273, 0x06930, 0x07337, 0x06aa0,
    0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160, 0x0e968, 0x0d520,
    0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
    0x0d520,
  ];

  /// 公历 → 农历；超出 1900–2100 范围返回 null
  static LunarDate? fromSolar(DateTime solar) {
    final d = DateTime(solar.year, solar.month, solar.day);
    if (d.isBefore(_base) || d.year > 2100) return null;

    var offset = d.difference(_base).inDays;
    var year = 1900;
    var temp = 0;
    for (; year < 2101 && offset > 0; year++) {
      temp = _daysInYear(year);
      offset -= temp;
    }
    if (offset < 0) {
      offset += temp;
      year--;
    }

    final leap = _leapMonthOf(year);
    var isLeap = false;
    var month = 1;
    for (; month < 13 && offset > 0; month++) {
      if (leap > 0 && month == leap + 1 && !isLeap) {
        month--;
        isLeap = true;
        temp = _leapDays(year);
      } else {
        temp = _daysInMonth(year, month);
      }
      if (isLeap && month == leap + 1) isLeap = false;
      offset -= temp;
    }
    // 恰好落在闰月边界：整年天数归位时判定为闰月
    if (offset == 0 && leap > 0 && month == leap + 1) {
      if (isLeap) {
        isLeap = false;
      } else {
        isLeap = true;
        month--;
      }
    }
    if (offset < 0) {
      offset += temp;
      month--;
    }
    return LunarDate(
      year: year,
      month: month,
      day: offset + 1,
      isLeapMonth: isLeap,
    );
  }

  /// 农历日的简写：初一返回“X月”（闰月加“闰”前缀），其余返回“初二”…“三十”
  static String dayName(LunarDate l) {
    const monthNames = [
      '正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊',
    ];
    if (l.day == 1) {
      return '${l.isLeapMonth ? '闰' : ''}${monthNames[l.month - 1]}月';
    }
    const tens = ['初', '十', '廿', '卅'];
    const ones = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    if (l.day == 10) return '初十';
    if (l.day == 20) return '二十';
    if (l.day == 30) return '三十';
    return '${tens[l.day ~/ 10]}${ones[l.day % 10]}';
  }

  static int _daysInYear(int y) {
    var sum = 348; // 12 个小月 29 天的底数，大月逐月 +1
    for (var bit = 0x8000; bit > 0x8; bit >>= 1) {
      if (_info[y - 1900] & bit != 0) sum++;
    }
    return sum + _leapDays(y);
  }

  static int _leapMonthOf(int y) => _info[y - 1900] & 0xf;

  static int _leapDays(int y) {
    if (_leapMonthOf(y) == 0) return 0;
    return _info[y - 1900] & 0x10000 != 0 ? 30 : 29;
  }

  static int _daysInMonth(int y, int m) =>
      _info[y - 1900] & (0x10000 >> m) != 0 ? 30 : 29;
}
