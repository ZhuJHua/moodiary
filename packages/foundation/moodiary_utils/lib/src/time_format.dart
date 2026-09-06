import 'package:intl/intl.dart';

class TimeFormat {
  static String mediaDuration(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '$m:$ss';
  }

  static String mediaPosition(Duration position, Duration duration) =>
      duration <= Duration.zero
      ? mediaDuration(position)
      : '${mediaDuration(position)} / ${mediaDuration(duration)}';

  static String fullDateTime(DateTime time) =>
      DateFormat.yMMMMEEEEd().add_Hms().format(time.toLocal());

  static String fullDate(DateTime time) =>
      DateFormat.yMMMMEEEEd().format(time.toLocal());

  static String longDateTime(DateTime time) =>
      DateFormat.yMMMMd().add_Hm().format(time.toLocal());

  static String longDate(DateTime time) =>
      DateFormat.yMMMMd().format(time.toLocal());

  static String listDateTime(DateTime time) =>
      DateFormat.yMd().add_Hm().format(time.toLocal());

  static String anchorDate(DateTime time) =>
      DateFormat.yMd().format(time.toLocal());

  static String weekdayTimeHms(DateTime time) =>
      DateFormat.E().add_Hms().format(time.toLocal());

  static String cardDate(DateTime time) =>
      DateFormat.MMMEd().format(time.toLocal());

  static String mediumDate(DateTime time) =>
      DateFormat.yMMMd().format(time.toLocal());

  static String monthDay(DateTime time) =>
      DateFormat.MMMd().format(time.toLocal());

  static String monthAbbr(DateTime time) =>
      DateFormat.MMM().format(time.toLocal());

  static String isoDate(DateTime time) {
    final t = time.toLocal();
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '${t.year}-$m-$d';
  }

  static String timeHms(DateTime time) =>
      DateFormat.Hms().format(time.toLocal());

  static String clock(DateTime time) => DateFormat.Hm().format(time.toLocal());

  static String compactDateTime(DateTime time) {
    final t = time.toLocal();
    final pattern = t.year == DateTime.now().year
        ? DateFormat.Md()
        : DateFormat.yMd();
    return pattern.add_Hm().format(t);
  }

  static String monthTitle(DateTime time) =>
      DateFormat.yMMMM().format(time.toLocal());

  static String weekdayShort(DateTime time) =>
      DateFormat.E().format(time.toLocal());

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
