import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';

void main() {
  group('heatmapLevelResolver', () {
    test('有效日不足 8 天时按篇数分级，第一格就有中等深度', () {
      final level = heatmapLevelResolver(const [10, 20, 30]);
      expect(level(1, 10), 2);
      expect(level(2, 20), 3);
      expect(level(5, 30), 4);
    });

    test('字数没有分布（p25 == p75）时退回按篇数，不把所有格子压成同一级', () {
      // 每天都写同样长度的一句话：按字数分位数会让四级全落到同一档。
      final level = heatmapLevelResolver(List.filled(30, 42));
      expect(level(1, 42), 2);
      expect(level(3, 42), 4);
    });

    test('字数有分布时按分位数铺满四级', () {
      final words = [for (var i = 1; i <= 40; i++) i * 50];
      final level = heatmapLevelResolver(words);
      final produced = {for (final w in words) level(1, w)};
      expect(produced, {1, 2, 3, 4}, reason: '四级都要用上，否则梯度是假的');
      // 单调：字数越多级别不降。
      var last = 0;
      for (final w in words) {
        final l = level(1, w);
        expect(l, greaterThanOrEqualTo(last));
        last = l;
      }
    });

    test('分级只看字数，不受篇数影响（一天三篇短句不该顶到最深）', () {
      final words = [for (var i = 1; i <= 40; i++) i * 50];
      final level = heatmapLevelResolver(words);
      expect(level(3, 50), level(1, 50));
    });
  });
}
