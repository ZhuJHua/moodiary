import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/application/auto_sync_watcher.dart';
import 'package:moodiary_sync/src/data/sync.dart';

/// 轮询空转短路与去抖重排的纯函数判定（watcher 本体依赖 getIt，不做实例级单测）。
void main() {
  group('clearsPendingLocal — 何时能清「本地有待推」', () {
    const clean = SyncReport(elapsed: .zero);
    test('干净一轮 → 清', () {
      expect(
        AutoSyncWatcher.clearsPendingLocal(clean, dirtyDuringSync: false),
        isTrue,
      );
    });

    test('同步期间又有写入 → 不清', () {
      expect(
        AutoSyncWatcher.clearsPendingLocal(clean, dirtyDuringSync: true),
        isFalse,
      );
    });

    test('push 因日记打开中跳过了条目 → 不清（关闭日记后还要推）', () {
      const skipped = SyncReport(elapsed: .zero, skippedOpen: 1);
      expect(
        AutoSyncWatcher.clearsPendingLocal(skipped, dirtyDuringSync: false),
        isFalse,
      );
    });
  });

  group('pollDelaySeconds — 探测失败退避', () {
    test('无失败 → 基础间隔', () {
      expect(AutoSyncWatcher.pollDelaySeconds(base: 30, failStreak: 0), 30);
    });

    test('每次失败翻倍', () {
      expect(AutoSyncWatcher.pollDelaySeconds(base: 30, failStreak: 1), 60);
      expect(AutoSyncWatcher.pollDelaySeconds(base: 30, failStreak: 2), 120);
      expect(AutoSyncWatcher.pollDelaySeconds(base: 30, failStreak: 4), 480);
    });

    test('封顶 10 分钟，且大 streak 不溢出', () {
      expect(AutoSyncWatcher.pollDelaySeconds(base: 30, failStreak: 5), 600);
      expect(AutoSyncWatcher.pollDelaySeconds(base: 30, failStreak: 40), 600);
      expect(AutoSyncWatcher.pollDelaySeconds(base: 600, failStreak: 1), 600);
    });
  });

  group('shouldRearm — 排定的推送只提前不推后', () {
    final base = DateTime(2026, 9, 4, 12);

    test('没有排定 → 排', () {
      expect(
        AutoSyncWatcher.shouldRearm(currentDue: null, newDue: base),
        isTrue,
      );
    });

    test('关闭日记的 1.5 秒不被随后分类改动的 5 秒顶掉', () {
      final close = base.add(const Duration(milliseconds: 1500));
      final change = base.add(const Duration(seconds: 5));
      expect(
        AutoSyncWatcher.shouldRearm(currentDue: close, newDue: change),
        isFalse,
      );
    });

    test('更早的到点替换掉已排定的', () {
      final change = base.add(const Duration(seconds: 5));
      final close = base.add(const Duration(milliseconds: 1500));
      expect(
        AutoSyncWatcher.shouldRearm(currentDue: change, newDue: close),
        isTrue,
      );
    });

    test('同一时刻不重排', () {
      expect(
        AutoSyncWatcher.shouldRearm(currentDue: base, newDue: base),
        isFalse,
      );
    });
  });

  const stat = 'webdav|2026-07-16T00:00:00.000Z';
  int minutes(int m) => m * 60 * 1000;

  bool skip({
    String preStat = stat,
    String? cachedStat = stat,
    bool pendingLocal = false,
    int lastSyncMs = 1,
    int? nowMs,
    int pollSeconds = 30,
  }) => AutoSyncWatcher.shouldSkipPoll(
    preStat: preStat,
    cachedStat: cachedStat,
    pendingLocal: pendingLocal,
    lastSyncMs: lastSyncMs,
    nowMs: nowMs ?? lastSyncMs + minutes(1),
    pollSeconds: pollSeconds,
  );

  test('远端未变 + 无待推 + 未超兜底窗 → 跳过', () {
    expect(skip(), isTrue);
  });

  test('本地有待推变更 → 不跳过', () {
    expect(skip(pendingLocal: true), isFalse);
  });

  test('远端指纹变化 / 无缓存 → 不跳过', () {
    expect(skip(cachedStat: 'webdav|other'), isFalse);
    expect(skip(cachedStat: null), isFalse);
    expect(skip(cachedStat: ''), isFalse);
  });

  test('换后端（指纹前缀不同）→ 不跳过', () {
    expect(skip(preStat: 's3|2026-07-16T00:00:00.000Z'), isFalse);
  });

  test('从未成功同步过 → 不跳过', () {
    expect(skip(lastSyncMs: 0), isFalse);
  });

  test('距上次成功同步超过 10 个轮询周期 → 强制全量兜底', () {
    // Last-Modified 秒级粒度可能漏判同秒并发写，定期强制全量保证最终收敛。
    expect(skip(lastSyncMs: 1, nowMs: 1 + minutes(5), pollSeconds: 30), isTrue);
    expect(
      skip(lastSyncMs: 1, nowMs: 1 + minutes(5) + 1000, pollSeconds: 30),
      isFalse,
    );
  });

  test('兜底窗上限 30 分钟，不随轮询间隔无限放大', () {
    // 间隔 1 小时 × 10 = 10 小时 → 收敛保证不可接受，夹到 30 分钟。
    expect(
      skip(lastSyncMs: 1, nowMs: 1 + minutes(30), pollSeconds: 3600),
      isTrue,
    );
    expect(
      skip(lastSyncMs: 1, nowMs: 1 + minutes(30) + 1000, pollSeconds: 3600),
      isFalse,
    );
  });
}
