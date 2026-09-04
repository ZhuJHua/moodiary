import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';

/// 日志页的显示单元：一次同步（[SyncLogRun]）或落在任何一次之外的散落事件
/// （[SyncLogSingle]，如轮询探测失败、密钥补传）。
sealed class SyncLogEntry {
  const SyncLogEntry();

  DateTime get at;

  bool get hasProblem;
}

/// `syncStart` 到 `syncEnd` 之间的一段（含首尾），前面紧挨的 `lockAcquire` 与后面
/// 紧挨的 `lockRelease` 一并收进来。[events] 按时间**升序**——读一次同步是顺着读的，
/// 页面整体的新→旧只作用在条目之间。
class SyncLogRun extends SyncLogEntry {
  final SyncEvent start;
  final SyncEvent? end;
  final List<SyncEvent> events;

  const SyncLogRun({
    required this.start,
    required this.end,
    required this.events,
  });

  @override
  DateTime get at => start.at;

  /// payload 里的 `direction`：push / pull / restore / re-cipher。
  String? get direction => _str(start.payload, 'direction');

  /// payload 里的 `trigger`（枚举名）；旧日志没有这个字段。
  String? get trigger => _str(start.payload, 'trigger');

  /// 没等到 syncEnd：还在跑，或进程当时被杀。
  bool get open => end == null;

  SyncOutcomeKind? get outcome {
    final end = this.end;
    if (end == null) return null;
    if (end.level == .error) return .failed;
    if (end.reason == .stopped || end.payload?['cancelled'] == true) {
      return .stopped;
    }
    if (_int(end.payload, 'failed') > 0) return .partial;
    return changedCount == 0 ? .upToDate : .changed;
  }

  /// 条目变更数（日记 + 分类 + 媒体信息），来自 syncEnd payload。
  int get changedCount =>
      _int(end?.payload, 'diaryCount') +
      _int(end?.payload, 'categoryCount') +
      _int(end?.payload, 'mediaInfoCount');

  int get diaryCount => _int(end?.payload, 'diaryCount');
  int get mediaCount => _int(end?.payload, 'mediaCount');
  int get failedCount => _int(end?.payload, 'failed');

  Duration? get elapsed {
    final ms = end?.payload?['elapsedMs'];
    return ms is int ? Duration(milliseconds: ms) : null;
  }

  @override
  bool get hasProblem => events.any((e) => e.level != .info);
}

class SyncLogSingle extends SyncLogEntry {
  final SyncEvent event;

  const SyncLogSingle(this.event);

  @override
  DateTime get at => event.at;

  @override
  bool get hasProblem => event.level != .info;
}

String? _str(Map<String, Object?>? payload, String key) {
  final v = payload?[key];
  return v is String && v.isNotEmpty ? v : null;
}

int _int(Map<String, Object?>? payload, String key) {
  final v = payload?[key];
  return v is int ? v : 0;
}

/// 把一天的事件（任意顺序）折成显示条目，**最新在前**。
///
/// 规则：`syncStart` 开一段，`syncEnd` 收一段；段外紧挨着的 `lockAcquire` 归入
/// 下一段、`lockRelease` 归入上一段（引擎抢锁在 start 之前、释放在 end 之后）；
/// 其它段外事件各自独立。没等到 end 的段照样成段（[SyncLogRun.open]）。
List<SyncLogEntry> groupSyncRuns(Iterable<SyncEvent> events) {
  final sorted = events.toList()..sort((a, b) => a.at.compareTo(b.at));
  final out = <SyncLogEntry>[];
  // 等着并入下一段的 lockAcquire。
  final pendingLocks = <SyncEvent>[];
  SyncEvent? runStart;
  List<SyncEvent>? runEvents;

  void flushPending() {
    for (final e in pendingLocks) {
      out.add(SyncLogSingle(e));
    }
    pendingLocks.clear();
  }

  void closeRun(SyncEvent? end) {
    if (runStart == null) return;
    out.add(SyncLogRun(start: runStart!, end: end, events: runEvents!));
    runStart = null;
    runEvents = null;
  }

  for (final e in sorted) {
    if (runStart != null) {
      runEvents!.add(e);
      if (e.kind == .syncEnd) closeRun(e);
      continue;
    }
    switch (e.kind) {
      case .syncStart:
        runStart = e;
        runEvents = [...pendingLocks, e];
        pendingLocks.clear();
      case .lockAcquire:
        pendingLocks.add(e);
      case .lockRelease when out.isNotEmpty && out.last is SyncLogRun:
        // 刚收完一段：释放锁属于它。
        final last = out.removeLast() as SyncLogRun;
        out.add(
          SyncLogRun(
            start: last.start,
            end: last.end,
            events: [...last.events, e],
          ),
        );
      default:
        flushPending();
        out.add(SyncLogSingle(e));
    }
  }
  closeRun(null);
  flushPending();
  return out.reversed.toList();
}

/// 段内连续同 kind 的事件折成组（≥2 条），单条保持原样。保持输入顺序。
List<Object> foldSameKind(List<SyncEvent> events) {
  final entries = <Object>[];
  var i = 0;
  while (i < events.length) {
    var j = i + 1;
    while (j < events.length && events[j].kind == events[i].kind) {
      j++;
    }
    final run = events.sublist(i, j);
    entries.add(run.length >= 2 ? run : run.first);
    i = j;
  }
  return entries;
}
