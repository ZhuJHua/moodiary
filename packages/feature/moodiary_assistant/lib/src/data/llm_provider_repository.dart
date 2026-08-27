import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

/// Provider 元数据存 SQLite；**API Key 存 SecureStorage**，按 `llm_key_<id>` 读写，
/// 删除 Provider 时一并清除。
class LlmProviderRepository {
  LlmProviderRepository._(this._db);

  factory LlmProviderRepository.get() => _instance;

  @visibleForTesting
  LlmProviderRepository.forTesting(this._db);

  static final LlmProviderRepository _instance = ._(MoodiaryDatabase.get());

  final MoodiaryDatabase _db;

  static String _keyOf(String id) => 'llm_key_$id';

  final StreamController<void> _events = StreamController<void>.broadcast();

  /// 单例随应用整个生命周期存活，故此 controller 不主动关闭。
  Stream<void> get providerEvents => _events.stream;

  static LlmProvider _toProvider(LlmProviderRow r) => LlmProvider(
    id: r.id,
    name: r.name,
    type: r.type,
    baseUrl: r.baseUrl,
    defaultModel: r.defaultModel,
    createdAt: dbToTime(r.createdAt),
    sortOrder: r.sortOrder,
    presetId: r.presetId,
    models: dbToStringList(r.modelsJson),
    toolCall: r.toolCall != 0,
    reasoning: r.reasoning != 0,
    attachment: r.attachment != 0,
  );

  static LlmProvidersCompanion _toCompanion(LlmProvider p) =>
      LlmProvidersCompanion.insert(
        id: p.id,
        name: p.name,
        type: p.type,
        baseUrl: p.baseUrl,
        defaultModel: p.defaultModel,
        createdAt: dbTime(p.createdAt),
        sortOrder: p.sortOrder,
        presetId: Value(p.presetId),
        modelsJson: Value(dbStringList(p.models)),
        toolCall: Value(p.toolCall ? 1 : 0),
        reasoning: Value(p.reasoning ? 1 : 0),
        attachment: Value(p.attachment ? 1 : 0),
      );

  /// 全部 Provider，按 [LlmProvider.sortOrder]、再按创建时间排序。
  Future<List<LlmProvider>> getAllProviders() async {
    final rows =
        await (_db.select(_db.llmProviders)..orderBy([
              (p) => OrderingTerm.asc(p.sortOrder),
              (p) => OrderingTerm.asc(p.createdAt),
            ]))
            .get();
    return [for (final r in rows) _toProvider(r)];
  }

  Future<LlmProvider?> getProvider(String id) async {
    final row = await (_db.select(
      _db.llmProviders,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toProvider(row);
  }

  Future<void> upsertProvider(LlmProvider provider) async {
    await _db
        .into(_db.llmProviders)
        .insertOnConflictUpdate(_toCompanion(provider));
    _events.add(null);
  }

  /// 删除 Provider，并清除其 API Key；若删的是当前激活项则清空激活指针。
  Future<void> deleteProvider(String id) async {
    await (_db.delete(_db.llmProviders)..where((p) => p.id.equals(id))).go();
    await removeKey(id);
    if (MoodiaryKVs.assistantActiveProviderId.get() == id) {
      MoodiaryKVs.assistantActiveProviderId.set('');
    }
    _events.add(null);
  }

  /// 按给定顺序重写全部 [LlmProvider.sortOrder]。整批一个事务（drift 的 batch 自带）、
  /// 只发一次事件 —— 逐条 upsert 会发 N 次刷新事件，列表在拖完的那一帧连闪 N 下。
  Future<void> reorderProviders(List<String> orderedIds) async {
    await _db.batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        final id = orderedIds[i];
        b.update(
          _db.llmProviders,
          LlmProvidersCompanion(sortOrder: Value(i)),
          where: (p) => p.id.equals(id),
        );
      }
    });
    _events.add(null);
  }

  /// 追加到列表末尾时用的 sortOrder（当前最大值 + 1）。
  Future<int> nextSortOrder() async {
    final maxOrder = _db.llmProviders.sortOrder.max();
    final row = await (_db.selectOnly(
      _db.llmProviders,
    )..addColumns([maxOrder])).getSingle();
    return (row.read(maxOrder) ?? -1) + 1;
  }

  Future<String?> getKey(String id) => ISecureKVStorage.get().get(_keyOf(id));

  Future<void> setKey(String id, String value) =>
      ISecureKVStorage.get().set(_keyOf(id), value);

  Future<void> removeKey(String id) =>
      ISecureKVStorage.get().remove(_keyOf(id));

  /// 当前激活的 Provider。激活指针缺失或失效时回退到列表首个；列表为空返回 null。
  Future<LlmProvider?> getActiveProvider() async {
    final id = MoodiaryKVs.assistantActiveProviderId.get();
    if (id != null && id.isNotEmpty) {
      final active = await getProvider(id);
      if (active != null) return active;
    }
    final all = await getAllProviders();
    return all.isEmpty ? null : all.first;
  }
}
