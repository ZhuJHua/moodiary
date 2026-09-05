import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';

/// 日志页的显示单元：一次同步（[SyncLogRun]）或落在任何一次之外的散落事件
/// （[SyncLogSingle]，如轮询探测失败、密钥补传）。
sealed class SyncLogEntry {
  const SyncLogEntry();

  DateTime get at;

  bool get hasProblem;
}

/// 一次同步 = 引擎一次 `_exclusive` 会话：从 `lockAcquire` 到 `lockRelease`，中间
/// 是一对或两对 `syncStart / syncEnd`（双向同步 = pull + push 共用一把锁）。没有锁的
/// 场景（归档导入、局域网接收）以 `syncStart / syncEnd` 自成一段。[events] 按时间
/// **升序**——读一次同步是顺着读的，页面整体的新→旧只作用在条目之间。
class SyncLogRun extends SyncLogEntry {
  final List<SyncEvent> events;
  final List<SyncEvent> starts;
  final List<SyncEvent> ends;

  /// 还没等到收尾（锁未释放 / start 多于 end）：还在跑，或进程当时被杀。
  final bool open;

  const SyncLogRun({
    required this.events,
    required this.starts,
    required this.ends,
    required this.open,
  });

  @override
  DateTime get at => events.first.at;

  /// 段内出现过的方向（push / pull / restore / re-cipher），按出现顺序。
  List<String> get directions => [
    for (final s in starts) ?_str(s.payload, 'direction'),
  ];

  /// pull + push 都有 → 一次双向同步。
  bool get bidirectional =>
      directions.contains('pull') && directions.contains('push');

  /// payload 里的 `trigger`（枚举名）；旧日志没有这个字段。
  String? get trigger =>
      starts.isEmpty ? null : _str(starts.first.payload, 'trigger');

  /// 连 syncStart 都没有：抢锁就失败了。
  bool get neverStarted => starts.isEmpty;

  SyncOutcomeKind? get outcome {
    if (open) return null;
    if (neverStarted || ends.any((e) => e.level == .error)) return .failed;
    if (ends.any(
      (e) => e.reason == .stopped || e.payload?['cancelled'] == true,
    )) {
      return .stopped;
    }
    if (failedCount > 0) return .partial;
    return pushedCount + pulledCount == 0 ? .upToDate : .changed;
  }

  int _sum(String key, {bool Function(String? direction)? where}) {
    var n = 0;
    for (final e in ends) {
      if (where != null && !where(_str(e.payload, 'direction'))) continue;
      n += _int(e.payload, key);
    }
    return n;
  }

  /// 上行条目变更数（日记 + 分类 + 常用地点 + 媒体信息）。
  int get pushedCount =>
      _sum('diaryCount', where: (d) => d == 'push') +
      _sum('categoryCount', where: (d) => d == 'push') +
      _sum('placeCount', where: (d) => d == 'push') +
      _sum('mediaInfoCount', where: (d) => d == 'push');

  /// 下行条目变更数（pull / restore）。
  int get pulledCount =>
      _sum('diaryCount', where: (d) => d != 'push') +
      _sum('categoryCount', where: (d) => d != 'push') +
      _sum('placeCount', where: (d) => d != 'push') +
      _sum('mediaInfoCount', where: (d) => d != 'push');

  int get mediaCount => _sum('mediaCount');
  int get failedCount => _sum('failed');

  /// 整轮墙钟耗时（含抢锁 / 释放锁），首尾事件之差。
  Duration get elapsed => events.last.at.difference(events.first.at);

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

/// 抢锁失败的尝试没有 syncStart 也没有 lockRelease：下一次 `lockAcquire` 若与上一条
/// 事件隔了超过这个时长，视作新的一次。引擎的 4 次重试相隔 3 秒，远小于此。
const Duration _acquireGap = Duration(seconds: 20);

/// 把一天的事件（任意顺序）折成显示条目，**最新在前**。
///
/// 状态机：`lockAcquire` 或 `syncStart` 开一段；开段后的事件一律归段。锁开的段在
/// `lockRelease` 收尾（含 releaseFailed 的 warn），无锁的段在 `syncEnd` 收尾。
/// 段外其它事件各自独立。没等到收尾的段照样成段（[SyncLogRun.open]）。
List<SyncLogEntry> groupSyncRuns(Iterable<SyncEvent> events) {
  final sorted = events.toList()..sort((a, b) => a.at.compareTo(b.at));
  final out = <SyncLogEntry>[];

  List<SyncEvent>? session;
  var lockOpened = false;
  var starts = <SyncEvent>[];
  var ends = <SyncEvent>[];

  void open(SyncEvent e, {required bool byLock}) {
    session = [e];
    lockOpened = byLock;
    starts = byLock ? [] : [e];
    ends = [];
  }

  void close({required bool finished}) {
    final s = session;
    if (s == null) return;
    out.add(
      SyncLogRun(
        events: s,
        starts: starts,
        ends: ends,
        open: !finished || starts.length > ends.length,
      ),
    );
    session = null;
  }

  for (final e in sorted) {
    final s = session;
    if (s == null) {
      switch (e.kind) {
        case .lockAcquire:
          open(e, byLock: true);
        case .syncStart:
          open(e, byLock: false);
        default:
          out.add(SyncLogSingle(e));
      }
      continue;
    }
    // 抢锁失败的旧尝试悬着：隔得够久的下一次抢锁开新段，旧的按「已结束、从未开始」算。
    if (e.kind == .lockAcquire &&
        lockOpened &&
        starts.isEmpty &&
        e.at.difference(s.last.at) > _acquireGap) {
      close(finished: true);
      open(e, byLock: true);
      continue;
    }
    s.add(e);
    switch (e.kind) {
      case .syncStart:
        starts.add(e);
      case .syncEnd:
        ends.add(e);
        if (!lockOpened) close(finished: true);
      case .lockRelease:
        close(finished: true);
      default:
        break;
    }
  }
  // 收尾：有 start 没 end 的是还在跑（或被杀）；连 start 都没有的是抢锁失败的残留。
  close(finished: starts.isEmpty);
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
