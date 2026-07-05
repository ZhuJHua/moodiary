import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';

void main() {
  // 直接走全量构造：Diary.empty 依赖 Rust 的 uuidV7()，单测环境未初始化 RustLib。
  Diary diary(String id, {required DateTime time, DateTime? modified}) => Diary(
    id: id,
    title: '',
    content: '',
    contentText: '',
    time: time,
    lastModified: modified ?? time,
    show: true,
    deleted: false,
    mood: 0.5,
    weather: const [],
    imageName: const [],
    audioName: const [],
    videoName: const [],
    tags: const [],
    position: const [],
    type: DiaryType.tiptap.value,
  );

  Category cat(String id) => Category(
    id: id,
    categoryName: id,
    lastModified: DateTime(2026),
    deleted: false,
  );

  group('diarySortComparator', () {
    final a = diary('a', time: DateTime(2026, 1, 1));
    final b = diary('b', time: DateTime(2026, 3, 1));
    final c = diary(
      'c',
      time: DateTime(2026, 2, 1),
      modified: DateTime(2026, 6, 1),
    );

    test('timeDesc puts newest first', () {
      final sorted = [a, b, c]..sort(diarySortComparator(DiarySort.timeDesc));
      expect(sorted.map((d) => d.id), ['b', 'c', 'a']);
    });

    test('timeAsc puts oldest first', () {
      final sorted = [b, a, c]..sort(diarySortComparator(DiarySort.timeAsc));
      expect(sorted.map((d) => d.id), ['a', 'c', 'b']);
    });

    test('lastModifiedDesc puts recently edited first', () {
      final sorted = [a, b, c]
        ..sort(diarySortComparator(DiarySort.lastModifiedDesc));
      expect(sorted.first.id, 'c');
    });

    test('equal keys fall back to isarId deterministically', () {
      final t = DateTime(2026, 5, 1);
      final x = diary('x', time: t);
      final y = diary('y', time: t);
      final desc = [x, y]..sort(diarySortComparator(DiarySort.timeDesc));
      final asc = [x, y]..sort(diarySortComparator(DiarySort.timeAsc));
      // 同刻并列时正倒序互为镜像（与库内 thenByIsarId(Desc) 一致）。
      expect(desc.map((d) => d.id), asc.reversed.map((d) => d.id));
    });
  });

  group('applyCategoryOrder', () {
    test('empty order keeps input order', () {
      final cats = [cat('b'), cat('a')];
      expect(applyCategoryOrder(cats, const []), same(cats));
    });

    test('orders by KV list and appends the rest by id', () {
      final cats = [cat('a'), cat('b'), cat('c'), cat('d')];
      final result = applyCategoryOrder(cats, const ['c', 'a']);
      expect(result.map((c) => c.id), ['c', 'a', 'b', 'd']);
    });

    test('stale ids in KV are ignored', () {
      final cats = [cat('a'), cat('b')];
      final result = applyCategoryOrder(cats, const ['zzz', 'b']);
      expect(result.map((c) => c.id), ['b', 'a']);
    });
  });
}
