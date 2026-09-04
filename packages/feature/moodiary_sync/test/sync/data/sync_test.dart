import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_sync/src/data/sync.dart';

void main() {
  group('SyncReport', () {
    test('defaults: no failure, not cancelled, nothing changed', () {
      const r = SyncReport(elapsed: .zero);
      expect(r.failed, 0);
      expect(r.cancelled, isFalse);
      expect(r.warning, isNull);
      expect(r.changedNothing, isTrue);
    });

    test('legacy totals are the sum of both directions', () {
      const r = SyncReport(
        pushed: SyncCounts(diaries: 2, categories: 1, mediaInfos: 3),
        pulled: SyncCounts(diaries: 1, mediaFiles: 4),
        elapsed: .zero,
      );
      expect(r.diaryCount, 3);
      expect(r.categoryCount, 1);
      expect(r.mediaInfoCount, 3);
      expect(r.changedNothing, isFalse);
    });

    test('toString includes both directions and appends a warning', () {
      const r = SyncReport(
        pushed: SyncCounts(diaries: 3, categories: 1),
        elapsed: Duration(milliseconds: 12),
        warning: '部分失败',
      );
      expect(r.toString(), contains('上行 日记 3 / 分类 1'));
      expect(r.toString(), contains('部分失败'));
    });
  });

  group('SyncReport.userSummary', () {
    test('nothing changed and clean → up-to-date phrase, never "0 条"', () {
      const r = SyncReport(elapsed: .zero);
      expect(r.userSummary(), l10n.sync.summaryUpToDate);
    });

    test('lists only non-zero parts, upload before download', () {
      const r = SyncReport(
        pushed: SyncCounts(diaries: 2, mediaFiles: 1),
        pulled: SyncCounts(categories: 1, mediaFiles: 2),
        elapsed: .zero,
      );
      expect(
        r.userSummary(),
        [
          l10n.sync.summaryUploadedDiaries(count: 2),
          l10n.sync.summaryDownloadedCategories(count: 1),
          l10n.sync.summaryMedia(count: 3),
        ].join(' · '),
      );
    });

    test('failures without changes: warning only, no up-to-date phrase', () {
      const r = SyncReport(elapsed: .zero, failed: 2);
      expect(r.userSummary(), l10n.sync.warnFailedSkipped(count: 2));
    });

    test('stopped mid-way keeps the counts and appends the stop note', () {
      const r = SyncReport(
        pushed: SyncCounts(diaries: 1),
        elapsed: .zero,
        cancelled: true,
      );
      expect(
        r.userSummary(),
        [
          l10n.sync.summaryUploadedDiaries(count: 1),
          l10n.sync.warnStopped,
        ].join(' · '),
      );
    });
  });

  group('SyncCounts', () {
    test('entry changes ignore media files', () {
      expect(const SyncCounts(mediaFiles: 3).hasEntryChanges, isFalse);
      expect(const SyncCounts(mediaFiles: 3).isEmpty, isFalse);
      expect(const SyncCounts(mediaInfos: 1).hasEntryChanges, isTrue);
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
