import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/application/sync_log_runs.dart';
import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';

void main() {
  final base = DateTime(2026, 9, 4, 14, 32);
  SyncEvent ev(
    int sec,
    SyncEventKind kind, {
    SyncEventLevel level = .info,
    SyncEventReason? reason,
    Map<String, Object?>? payload,
  }) => SyncEvent(
    at: base.add(Duration(seconds: sec)),
    level: level,
    kind: kind,
    reason: reason,
    payload: payload,
  );

  test('双向同步：抢锁、读清单、pull、push、释放锁折成一段', () {
    final entries = groupSyncRuns([
      ev(0, .lockAcquire),
      ev(0, .lockAcquire, reason: .casVerified),
      ev(1, .manifestRead, payload: {'entries': 26}),
      ev(1, .syncStart, payload: {'direction': 'pull', 'trigger': 'network'}),
      ev(2, .syncEnd, payload: {'direction': 'pull', 'failed': 0}),
      ev(2, .syncStart, payload: {'direction': 'push', 'trigger': 'network'}),
      ev(3, .diaryUpload),
      ev(
        4,
        .syncEnd,
        payload: {
          'direction': 'push',
          'diaryCount': 1,
          'mediaCount': 2,
          'failed': 0,
          'elapsedMs': 1300,
        },
      ),
      ev(5, .lockRelease),
    ]);
    expect(entries.length, 1);
    final run = entries.single as SyncLogRun;
    expect(run.events.length, 9);
    expect(run.events.first.kind, SyncEventKind.lockAcquire);
    expect(run.events.last.kind, SyncEventKind.lockRelease);
    expect(run.bidirectional, isTrue);
    expect(run.directions, ['pull', 'push']);
    expect(run.trigger, 'network');
    expect(run.outcome, SyncOutcomeKind.changed);
    expect(run.pushedCount, 1);
    expect(run.pulledCount, 0);
    expect(run.mediaCount, 2);
    expect(run.elapsed, const Duration(seconds: 5));
    expect(run.open, isFalse);
    expect(run.hasProblem, isFalse);
  });

  test('无锁的一段（归档导入）在 syncEnd 收尾', () {
    final entries = groupSyncRuns([
      ev(1, .syncStart, payload: {'direction': 'restore'}),
      ev(2, .diaryDownload),
      ev(3, .syncEnd, payload: {'direction': 'restore', 'diaryCount': 1}),
      ev(4, .keyfileUpload, level: .warn),
    ]);
    expect(entries.length, 2);
    final run = entries[1] as SyncLogRun;
    expect(run.directions, ['restore']);
    expect(run.pulledCount, 1);
    expect(run.outcome, SyncOutcomeKind.changed);
    expect(
      (entries[0] as SyncLogSingle).event.kind,
      SyncEventKind.keyfileUpload,
    );
  });

  test('段外事件独立成条，输入乱序也按时间归位，输出最新在前', () {
    final entries = groupSyncRuns([
      ev(9, .manifestRead, level: .warn, reason: .probeFailed),
      ev(1, .lockAcquire),
      ev(2, .syncStart, payload: {'direction': 'push'}),
      ev(3, .syncEnd, payload: {'direction': 'push', 'failed': 0}),
      ev(4, .lockRelease),
      ev(0, .keyfileUpload, level: .warn),
    ]);
    expect(entries.length, 3);
    expect(
      (entries[0] as SyncLogSingle).event.reason,
      SyncEventReason.probeFailed,
    );
    expect(entries[1], isA<SyncLogRun>());
    expect((entries[1] as SyncLogRun).outcome, SyncOutcomeKind.upToDate);
    expect(
      (entries[2] as SyncLogSingle).event.kind,
      SyncEventKind.keyfileUpload,
    );
    expect(entries[0].hasProblem, isTrue);
  });

  test('没等到释放锁的段：open，结果未知', () {
    final entries = groupSyncRuns([
      ev(0, .lockAcquire),
      ev(1, .syncStart, payload: {'direction': 'pull'}),
      ev(2, .manifestRead),
    ]);
    final run = entries.single as SyncLogRun;
    expect(run.open, isTrue);
    expect(run.outcome, isNull);
  });

  test('抢锁失败的尝试：没有 start，隔够久的下一次抢锁开新段', () {
    final entries = groupSyncRuns([
      ev(0, .lockAcquire, level: .warn, reason: .expiredLock),
      ev(3, .lockAcquire, level: .warn, reason: .expiredLock),
      ev(60, .lockAcquire),
      ev(61, .syncStart, payload: {'direction': 'push'}),
      ev(62, .syncEnd, payload: {'direction': 'push', 'failed': 0}),
      ev(63, .lockRelease),
    ]);
    expect(entries.length, 2);
    final failedAttempt = entries[1] as SyncLogRun;
    expect(failedAttempt.neverStarted, isTrue);
    expect(failedAttempt.outcome, SyncOutcomeKind.failed);
    expect(failedAttempt.events.length, 2);
    expect((entries[0] as SyncLogRun).outcome, SyncOutcomeKind.upToDate);
  });

  test('结果判定：异常中止 / 停止 / 有失败条目', () {
    SyncLogRun runWith(SyncEvent end) =>
        groupSyncRuns([
              ev(0, .lockAcquire),
              ev(1, .syncStart, payload: {'direction': 'push'}),
              end,
              ev(3, .lockRelease),
            ]).single
            as SyncLogRun;

    expect(
      runWith(ev(2, .syncEnd, level: .error, reason: .aborted)).outcome,
      SyncOutcomeKind.failed,
    );
    expect(
      runWith(ev(2, .syncEnd, reason: .stopped, payload: {'cancelled': true}))
          .outcome,
      SyncOutcomeKind.stopped,
    );
    final partial = runWith(
      ev(2, .syncEnd, payload: {'diaryCount': 1, 'failed': 2}),
    );
    expect(partial.outcome, SyncOutcomeKind.partial);
    expect(partial.failedCount, 2);
  });

  test('foldSameKind：连续同 kind ≥2 折组，单条保持原样', () {
    final folded = foldSameKind([
      ev(0, .diarySkip),
      ev(1, .diarySkip),
      ev(2, .diaryUpload),
      ev(3, .diarySkip),
    ]);
    expect(folded.length, 3);
    expect(folded[0], isA<List<SyncEvent>>());
    expect((folded[0] as List).length, 2);
    expect(folded[1], isA<SyncEvent>());
    expect(folded[2], isA<SyncEvent>());
  });
}
