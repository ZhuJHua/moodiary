import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/src/common/tile_plan.dart';

void main() {
  const planner = TilePlanner(imageSize: Size(8000, 6000));

  test('fit 比例：整图落到一屏几块 tile，sample 取到 8', () {
    // 8000 宽在 1440 物理像素的屏上 fit：每源像素 0.18 物理像素。
    final plan = planner.plan(
      visible: const Rect.fromLTWH(0, 0, 8000, 6000),
      physicalScale: 0.18,
    );
    // 1 → 2（0.36 ≤ 1.15）→ 4（0.72 ≤ 1.15），再翻是 1.44 超了：解出来每设备像素 1.39 个采样。
    expect(plan.sample, 4);
    expect(plan.visible.length, 4 * 3, reason: '2048 一格：4 列 3 行');
    expect(plan.prefetch, isEmpty);
  });

  test('放大到 1:1：只解视口相交的 tile，按离中心距离排序', () {
    final plan = planner.plan(
      visible: const Rect.fromLTWH(3000, 2000, 1440, 3200),
      physicalScale: 1,
    );
    expect(plan.sample, 1);
    expect(
      plan.visible.first.sourceRect.contains(const Offset(3720, 3600)),
      isTrue,
    );
    final rows = plan.visible.map((t) => t.row).toSet();
    expect(rows, {3, 4, 5, 6, 7, 8, 9, 10});
    expect(plan.prefetch, isNotEmpty);
    expect(
      plan.visible
          .map((t) => t.key)
          .toSet()
          .intersection(plan.prefetch.map((t) => t.key).toSet()),
      isEmpty,
    );
  });

  test('可见 tile 超上限就升一档 sample', () {
    const small = TilePlanner(imageSize: Size(8000, 6000), maxVisibleTiles: 4);
    final plan = small.plan(
      visible: const Rect.fromLTWH(0, 0, 8000, 6000),
      physicalScale: 1,
    );
    expect(plan.sample, 8);
    expect(plan.visible.length, lessThanOrEqualTo(4));
  });

  test('边缘 tile 被源图边界裁掉', () {
    final plan = planner.plan(
      visible: const Rect.fromLTWH(7000, 5000, 2000, 2000),
      physicalScale: 1,
    );
    final last = plan.visible.firstWhere((t) => t.row == 11 && t.col == 15);
    expect(last.sourceRect, const Rect.fromLTRB(7680, 5632, 8000, 6000));
  });
}
