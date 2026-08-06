import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/data/sync.dart';

void main() {
  group('SyncReport', () {
    test('defaults: no failure, not cancelled', () {
      const r = SyncReport(diaryCount: 1, categoryCount: 2, elapsed: .zero);
      expect(r.failed, 0);
      expect(r.cancelled, isFalse);
      expect(r.warning, isNull);
    });

    test('toString includes counts and appends a warning', () {
      const r = SyncReport(
        diaryCount: 3,
        categoryCount: 1,
        elapsed: Duration(milliseconds: 12),
        warning: '部分失败',
      );
      expect(r.toString(), contains('日记 3 条'));
      expect(r.toString(), contains('分类 1 条'));
      expect(r.toString(), contains('部分失败'));
    });
  });

  group('SyncException', () {
    test('carries message in toString', () {
      const e = SyncException('boom');
      expect(e.message, 'boom');
      expect(e.toString(), contains('boom'));
    });
  });
}
