import 'diary.dart';

enum SearchSort { relevance, timeDesc, timeAsc }

enum DateRangePreset { all, last7Days, last30Days, thisYear, custom }

/// 命中词在 [titleHighlight] / [excerpt] 里由这对哨兵字符包住（正文可能含标签，
/// 所以不用 `<b>`）。
const String searchHitStart = '';
const String searchHitEnd = '';

class DiarySearchHit {
  const DiarySearchHit({
    required this.diary,
    required this.titleHighlight,
    required this.excerpt,
  });

  final Diary diary;
  final String titleHighlight;
  final String excerpt;
}

List<(String, bool)> splitSearchHighlight(String marked) {
  final out = <(String, bool)>[];
  var rest = marked;
  while (rest.isNotEmpty) {
    final open = rest.indexOf(searchHitStart);
    if (open == -1) {
      out.add((rest, false));
      break;
    }
    if (open > 0) out.add((rest.substring(0, open), false));
    final close = rest.indexOf(searchHitEnd, open + 1);
    if (close == -1) {
      out.add((rest.substring(open + 1), true));
      break;
    }
    out.add((rest.substring(open + 1, close), true));
    rest = rest.substring(close + 1);
  }
  return out;
}
