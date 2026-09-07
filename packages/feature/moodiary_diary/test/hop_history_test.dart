import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary/src/presentation/detail/hop_history.dart';

void main() {
  group('HopHistory', () {
    test('reset 后为单条且在起点', () {
      final h = HopHistory()..reset('a');
      expect(h.length, 1);
      expect(h.atRoot, isTrue);
      expect(h.current?.diaryId, 'a');
    });

    test('push 追加并前移游标', () {
      final h = HopHistory()
        ..reset('a')
        ..push('b')
        ..push('a'); // 回环不去重：浏览器语义
      expect(h.length, 3);
      expect(h.cursor, 2);
      expect(h.atRoot, isFalse);
      expect(h.current?.diaryId, 'a');
    });

    test('回退后 push 截断前进分支', () {
      final h = HopHistory()
        ..reset('a')
        ..push('b')
        ..push('c')
        ..move(-1)
        ..move(-1); // 回到 a
      h.push('d');
      expect(h.length, 2);
      expect(h.current?.diaryId, 'd');
      expect(h.peek(-1)?.diaryId, 'a');
      expect(h.peek(1), isNull);
    });

    test('超上限丢最旧，游标仍指向最新', () {
      final h = HopHistory(max: 3)
        ..reset('a')
        ..push('b')
        ..push('c')
        ..push('d');
      expect(h.length, 3);
      expect(h.current?.diaryId, 'd');
      expect(h.peek(-1)?.diaryId, 'c');
      h
        ..move(-1)
        ..move(-1);
      expect(h.atRoot, isTrue);
      expect(h.current?.diaryId, 'b');
    });

    test('peek 越界返回 null', () {
      final h = HopHistory()..reset('a');
      expect(h.peek(-1), isNull);
      expect(h.peek(1), isNull);
    });

    test('dropNext 向后剔除并校正游标', () {
      final h = HopHistory()
        ..reset('a')
        ..push('b')
        ..push('c'); // cursor=2
      h.dropNext(-1); // b 已删
      expect(h.length, 2);
      expect(h.cursor, 1);
      expect(h.current?.diaryId, 'c');
      expect(h.peek(-1)?.diaryId, 'a');
    });

    test('dropNext 向前剔除不动游标', () {
      final h = HopHistory()
        ..reset('a')
        ..push('b')
        ..push('c')
        ..move(-1)
        ..move(-1); // 回到 a
      h.dropNext(1); // b 已删
      expect(h.cursor, 0);
      expect(h.current?.diaryId, 'a');
      expect(h.peek(1)?.diaryId, 'c');
    });

    test('scrollY 回填保留在条目上', () {
      final h = HopHistory()..reset('a');
      h.current?.scrollY = 120;
      h.push('b');
      h.move(-1);
      expect(h.current?.scrollY, 120);
    });
  });
}
