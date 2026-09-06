import 'package:moodiary_sync/src/application/sync_runner.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';

sealed class SyncLogEntry {
  const SyncLogEntry();

  DateTime get at;

  bool get hasProblem;
}

class SyncLogRun extends SyncLogEntry {
  final List<SyncEvent> events;
  final List<SyncEvent> starts;
  final List<SyncEvent> ends;

  final bool open;

  const SyncLogRun({
    required this.events,
    required this.starts,
    required this.ends,
    required this.open,
  });

  @override
  DateTime get at => events.first.at;

  List<String> get directions => [
    for (final s in starts) ?_str(s.payload, 'direction'),
  ];

  bool get bidirectional =>
      directions.contains('pull') && directions.contains('push');

  String? get trigger =>
      starts.isEmpty ? null : _str(starts.first.payload, 'trigger');

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

  int get pushedCount =>
      _sum('diaryCount', where: (d) => d == 'push') +
      _sum('categoryCount', where: (d) => d == 'push') +
      _sum('placeCount', where: (d) => d == 'push') +
      _sum('mediaInfoCount', where: (d) => d == 'push');

  int get pulledCount =>
      _sum('diaryCount', where: (d) => d != 'push') +
      _sum('categoryCount', where: (d) => d != 'push') +
      _sum('placeCount', where: (d) => d != 'push') +
      _sum('mediaInfoCount', where: (d) => d != 'push');

  int get mediaCount => _sum('mediaCount');
  int get failedCount => _sum('failed');

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

const Duration _acquireGap = Duration(seconds: 20);

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
  close(finished: starts.isEmpty);
  return out.reversed.toList();
}

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
