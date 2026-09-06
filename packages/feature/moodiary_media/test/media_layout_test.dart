import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_media/src/media_layout.dart';

MediaItem _item(String name, String diary, DateTime t) =>
    MediaItem(fileName: name, diaryId: diary, time: t);

void main() {
  final d1 = DateTime(2026, 9, 2, 10).toUtc();
  final d2 = DateTime(2026, 9, 1, 22).toUtc();

  group('MediaFlat.of', () {
    test('按本地日期分组，每组一个标题在前，格子按序', () {
      final flat = MediaFlat.of([
        _item('a', 'x', d1),
        _item('b', 'x', d1),
        _item('c', 'y', d2),
      ]);
      expect(flat.dates, [DateTime(2026, 9, 2), DateTime(2026, 9, 1)]);
      expect(flat.groups, [
        ['a', 'b'],
        ['c'],
      ]);
      expect(flat.entries.length, 5);
      expect(flat.entries[0], isA<MediaHeader>());
      expect(flat.entries[3], isA<MediaHeader>());
      expect((flat.entries[2] as MediaCell).index, 1);
    });

    test('key 能反查 index（插入 / 删除后按 key 找回 element）', () {
      final flat = MediaFlat.of([_item('a', 'x', d1)]);
      expect(flat.indexOfKey(flat.keys[1]), 1);
      expect(flat.indexOfKey(const ValueKey('nope')), isNull);
    });
  });

  group('GroupedGridLayout', () {
    final flat = MediaFlat.of([
      for (var i = 0; i < 4; i++) _item('a$i', 'x', d1),
      _item('c', 'y', d2),
    ]);
    final layout = GroupedGridLayout.compute(
      entries: flat.entries,
      crossAxisExtent: 316,
      columns: 3,
      spacing: 4,
      headerExtent: 40,
    );
    const tile = (316 - 8) / 3;

    test('标题整行宽，格子按列排，行满换行', () {
      final h = layout.getGeometryForChildIndex(0);
      expect(h.crossAxisExtent, 316);
      expect(h.mainAxisExtent, 40);
      final c0 = layout.getGeometryForChildIndex(1);
      final c2 = layout.getGeometryForChildIndex(3);
      final c3 = layout.getGeometryForChildIndex(4);
      expect(c0.scrollOffset, 40);
      expect(c2.crossAxisOffset, closeTo(2 * (tile + 4), 1e-9));
      expect(c3.scrollOffset, closeTo(40 + tile + 4, 1e-9));
      expect(c3.crossAxisOffset, 0);
    });

    test('半行之后的标题另起一行，总长收口正确', () {
      final h2 = layout.getGeometryForChildIndex(5);
      expect(h2.scrollOffset, closeTo(40 + (tile + 4) * 2, 1e-9));
      final last = layout.getGeometryForChildIndex(6);
      expect(layout.totalExtent, closeTo(last.scrollOffset + tile, 1e-9));
      expect(layout.computeMaxScrollOffset(7), layout.totalExtent);
    });

    test('二分定位可见范围：min 取尾在其后的第一个，max 取头在其前的最后一个', () {
      expect(layout.getMinChildIndexForScrollOffset(0), 0);
      expect(layout.getMinChildIndexForScrollOffset(40), 1);
      expect(layout.getMinChildIndexForScrollOffset(40 + tile + 0.5), 4);
      expect(layout.getMaxChildIndexForScrollOffset(41), 3);
      expect(layout.getMaxChildIndexForScrollOffset(1e9), 6);
      expect(layout.getMinChildIndexForScrollOffset(1e9), 7);
    });
  });
}
