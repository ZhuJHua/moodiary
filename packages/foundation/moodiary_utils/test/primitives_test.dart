import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

void main() {
  test('lru cache test', () {
    final lru = LRUCache<int, int>(maxSize: 3);
    lru.put(1, 1);
    lru.put(2, 2);
    lru.put(3, 3);
    expect(lru.size(), 3);
    lru.put(4, 4);
    expect(lru.size(), 3);
    expect(lru.get(1), null);
    expect(lru.get(2), 2);
    lru.put(5, 5);
    expect(lru.size(), 3);
    expect(lru.get(3), null);
    expect(lru.get(4), 4);
    expect(lru.get(5), 5);
  });

  test('uuidV7 前 48 位是毫秒时间戳（extractDateFromUUID 依赖此布局）', () {
    final before = DateTime.now().millisecondsSinceEpoch;
    final id = uuidV7();
    final after = DateTime.now().millisecondsSinceEpoch;
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ),
      ),
    );
    final ms = int.parse(id.replaceAll('-', '').substring(0, 12), radix: 16);
    expect(ms, inInclusiveRange(before, after));
  });

  group('TimeFormat', () {
    test('isoDate 补零且不随语言变化', () {
      expect(TimeFormat.isoDate(DateTime(2026, 7, 4)), '2026-07-04');
      expect(TimeFormat.isoDate(DateTime(2026, 11, 23)), '2026-11-23');
    });

    test('同一时刻的 UTC 与本地入参输出一致', () {
      final utc = DateTime.utc(2026, 7, 4, 12, 30, 15);
      expect(TimeFormat.isoDate(utc), TimeFormat.isoDate(utc.toLocal()));
      expect(
        TimeFormat.fullDateTime(utc),
        TimeFormat.fullDateTime(utc.toLocal()),
      );
      expect(TimeFormat.timeHms(utc), TimeFormat.timeHms(utc.toLocal()));
    });

    test('fullDateTime 精确到秒', () {
      final s = TimeFormat.fullDateTime(DateTime(2026, 7, 4, 1, 2, 3));
      expect(s, contains('02:03'));
    });

    test('relative：今天给时分，跨年给年月日', () {
      final today = TimeFormat.relative(.now());
      expect(RegExp(r'^\d{1,2}:\d{2}$').hasMatch(today), isTrue);
      expect(
        TimeFormat.relative(DateTime(2000, 5, 5, 10, 30)),
        contains('2000'),
      );
    });

    test('lunarDay：春节锚点与日常', () {
      expect(TimeFormat.lunarDay(DateTime(2023, 1, 22)), '春节');
      expect(TimeFormat.lunarDay(DateTime(2024, 2, 10)), '春节');
      expect(TimeFormat.lunarDay(DateTime(2025, 1, 29)), '春节');
      expect(TimeFormat.lunarDay(DateTime(2026, 2, 17)), '春节');
      expect(TimeFormat.lunarDay(DateTime(1900, 1, 31)), '春节');
      expect(TimeFormat.lunarDay(DateTime(2000, 1, 1)), '元旦');
      expect(TimeFormat.lunarDay(DateTime(2026, 9, 25)), '中秋节');
    });

    test('lunarDay：闰月初一', () {
      expect(TimeFormat.lunarDay(DateTime(2023, 3, 22)), '闰二月');
      expect(TimeFormat.lunarDay(DateTime(2025, 7, 25)), '闰六月');
    });

    test('lunarDay：农历节日压过日名', () {
      // 除夕可能落在腊月三十或廿九
      expect(TimeFormat.lunarDay(DateTime(2023, 1, 21)), '除夕');
      expect(TimeFormat.lunarDay(DateTime(2024, 2, 9)), '除夕');
      expect(TimeFormat.lunarDay(DateTime(2025, 1, 28)), '除夕');
      expect(TimeFormat.lunarDay(DateTime(2023, 2, 5)), '元宵节');
      expect(TimeFormat.lunarDay(DateTime(2024, 3, 11)), '龙头节');
      expect(TimeFormat.lunarDay(DateTime(2024, 4, 11)), '上巳节');
      expect(TimeFormat.lunarDay(DateTime(2023, 6, 22)), '端午节');
      expect(TimeFormat.lunarDay(DateTime(2023, 8, 22)), '七夕节');
      expect(TimeFormat.lunarDay(DateTime(2023, 8, 30)), '中元节');
      expect(TimeFormat.lunarDay(DateTime(2023, 9, 29)), '中秋节');
      expect(TimeFormat.lunarDay(DateTime(2025, 10, 6)), '中秋节');
      expect(TimeFormat.lunarDay(DateTime(2023, 10, 23)), '重阳节');
      expect(TimeFormat.lunarDay(DateTime(2024, 1, 18)), '腊八节');
    });

    test('lunarDay：公历节日压过农历日名，同日相撞时公历在前', () {
      expect(TimeFormat.lunarDay(DateTime(2026, 1, 1)), '元旦');
      expect(TimeFormat.lunarDay(DateTime(2026, 3, 8)), '妇女节');
      expect(TimeFormat.lunarDay(DateTime(2026, 5, 1)), '劳动节');
      expect(TimeFormat.lunarDay(DateTime(2026, 6, 1)), '儿童节');
      expect(TimeFormat.lunarDay(DateTime(2026, 10, 1)), '国庆节');
      // 2020-10-01 既是国庆节又是中秋节：公历节日先判
      expect(TimeFormat.lunarDay(DateTime(2020, 10, 1)), '国庆节');
      // tyme 没收录的公历节日不做特殊处理，落回农历日名
      expect(TimeFormat.lunarDay(DateTime(2026, 12, 25)), '十七');
    });

    test('lunarDay：节气只在当天返回节气名', () {
      expect(TimeFormat.lunarDay(DateTime(2026, 1, 20)), '大寒');
      expect(TimeFormat.lunarDay(DateTime(2026, 2, 4)), '立春');
      expect(TimeFormat.lunarDay(DateTime(2026, 4, 5)), '清明');
      expect(TimeFormat.lunarDay(DateTime(2026, 6, 21)), '夏至');
      expect(TimeFormat.lunarDay(DateTime(2026, 9, 23)), '秋分');
      expect(TimeFormat.lunarDay(DateTime(2026, 12, 22)), '冬至');
      // 换一年同样是当天命中
      expect(TimeFormat.lunarDay(DateTime(2023, 3, 21)), '春分');
      expect(TimeFormat.lunarDay(DateTime(2024, 5, 20)), '小满');
      // 次日回到农历日名：节气不是一个区间
      expect(TimeFormat.lunarDay(DateTime(2026, 2, 5)), '十八');
      expect(TimeFormat.lunarDay(DateTime(2026, 4, 6)), '十九');
    });

    test('lunarDay：非节日的初一回月名，其余回日名', () {
      expect(TimeFormat.lunarDay(DateTime(2023, 2, 20)), '二月');
      expect(TimeFormat.lunarDay(DateTime(2023, 12, 13)), '冬月');
      expect(TimeFormat.lunarDay(DateTime(2024, 1, 11)), '腊月');
      expect(TimeFormat.lunarDay(DateTime(2026, 1, 19)), '腊月');
      expect(TimeFormat.lunarDay(DateTime(2023, 11, 27)), '十五');
      expect(TimeFormat.lunarDay(DateTime(2000, 1, 2)), '廿六');
      expect(TimeFormat.lunarDay(DateTime(2024, 2, 2)), '廿三');
      expect(TimeFormat.lunarDay(DateTime(2026, 10, 4)), '廿四');
      expect(TimeFormat.lunarDay(DateTime(2026, 10, 7)), '廿七');
    });

    test('lunarDay：只看年月日，库里最早最晚的日期也算得出来', () {
      // 传进来的时刻不参与计算
      expect(TimeFormat.lunarDay(DateTime(2026, 2, 17, 23, 59)), '春节');
      expect(TimeFormat.lunarDay(DateTime(1900, 1, 1)), '腊月');
      expect(TimeFormat.lunarDay(DateTime(2100, 12, 31)), '腊月');
    });
  });
}
