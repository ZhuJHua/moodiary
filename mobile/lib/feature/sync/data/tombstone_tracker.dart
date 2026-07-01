import 'dart:convert';

import 'package:moodiary_core/moodiary_core.dart';

/// 跟踪每条 `deleted=true` 日记已向哪些**云后端**推过 tombstone。
/// 必须等所有已配置后端都收到 tombstone 才能从 Isar 清除该日记，否则切换后端后
/// 旧后端会残留「已删的日记」。形态 `{ "<diaryId>": ["webdav","s3"] }`，存进
/// [MoodiaryKVs.tombstonePushedBackends]；一次同步内内存增量改、结尾回写一次。
/// `persistentBackendId` 为 null 的后端不参与跟踪，引擎走旧的「推完即清」。
class TombstoneTracker {
  final Map<String, Set<String>> _data;
  bool _dirty = false;

  TombstoneTracker._(this._data);

  /// 从 KV 加载快照。容错：解析失败当作空表（不阻塞同步）。
  static TombstoneTracker load() {
    final raw = MoodiaryKVs.tombstonePushedBackends.get();
    if (raw == null || raw.isEmpty) return TombstoneTracker._({});
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return TombstoneTracker._({});
      final m = <String, Set<String>>{};
      decoded.forEach((k, v) {
        if (k is! String || v is! List) return;
        m[k] = v.whereType<String>().toSet();
      });
      return TombstoneTracker._(m);
    } catch (_) {
      return TombstoneTracker._({});
    }
  }

  /// 该 diary 已推过的 backend 集合（只读）。
  Set<String> pushedFor(String diaryId) =>
      _data[diaryId] ?? const <String>{};

  /// 记录 [diaryId] 已经向 [backendId] 推过 tombstone。
  void markPushed(String diaryId, String backendId) {
    final set = _data.putIfAbsent(diaryId, () => <String>{});
    if (set.add(backendId)) _dirty = true;
  }

  /// 引擎确认从 Isar 删除 tombstone 时，连带从跟踪表里清掉这些 id。
  void clear(Iterable<String> diaryIds) {
    for (final id in diaryIds) {
      if (_data.remove(id) != null) _dirty = true;
    }
  }

  /// 增量写回 KV（无修改时跳过）。
  Future<void> save() async {
    if (!_dirty) return;
    if (_data.isEmpty) {
      await MoodiaryKVs.tombstonePushedBackends.set('{}');
    } else {
      final encoded = jsonEncode(
        _data.map((k, v) => MapEntry(k, v.toList())),
      );
      await MoodiaryKVs.tombstonePushedBackends.set(encoded);
    }
    _dirty = false;
  }
}
