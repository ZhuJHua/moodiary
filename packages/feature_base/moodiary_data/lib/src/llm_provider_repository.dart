
import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

/// Provider 元数据存 Isar；**API Key 存 SecureStorage**，按 `llm_key_<id>` 读写，
/// 删除 Provider 时一并清除。
class LlmProviderRepository {
  LlmProviderRepository._(this._isar);

  factory LlmProviderRepository.get() => _instance;

  @visibleForTesting
  LlmProviderRepository.forTesting(this._isar);

  static final LlmProviderRepository _instance = ._(IsarDatabase.get().isar);

  final Isar _isar;

  static String _keyOf(String id) => 'llm_key_$id';

  final StreamController<void> _events = StreamController<void>.broadcast();

  /// 单例随应用整个生命周期存活，故此 controller 不主动关闭。
  Stream<void> get providerEvents => _events.stream;

  /// 全部 Provider，按 [LlmProvider.sortOrder]、再按创建时间排序。
  Future<List<LlmProvider>> getAllProviders() {
    return _isar.llmProviders
        .where()
        .sortBySortOrder()
        .thenByCreatedAt()
        .findAllAsync();
  }

  Future<LlmProvider?> getProvider(String id) {
    return _isar.llmProviders.getAsync(id);
  }

  Future<void> upsertProvider(LlmProvider provider) async {
    await _isar.writeAsync((isar) {
      isar.llmProviders.put(provider);
    });
    _events.add(null);
  }

  /// 删除 Provider，并清除其 API Key；若删的是当前激活项则清空激活指针。
  Future<void> deleteProvider(String id) async {
    await _isar.writeAsync((isar) {
      isar.llmProviders.delete(id);
    });
    await removeKey(id);
    if (MoodiaryKVs.assistantActiveProviderId.get() == id) {
      MoodiaryKVs.assistantActiveProviderId.set('');
    }
    _events.add(null);
  }

  /// 按给定顺序重写全部 [LlmProvider.sortOrder]。整批一个事务、只发一次事件 ——
  /// 逐条 upsert 会发 N 次刷新事件，列表在拖完的那一帧连闪 N 下。
  Future<void> reorderProviders(List<String> orderedIds) async {
    await _isar.writeAsync((isar) {
      for (var i = 0; i < orderedIds.length; i++) {
        final provider = isar.llmProviders.get(orderedIds[i]);
        if (provider != null) {
          isar.llmProviders.put(provider.copyWith(sortOrder: i));
        }
      }
    });
    _events.add(null);
  }

  /// 追加到列表末尾时用的 sortOrder（当前最大值 + 1）。
  Future<int> nextSortOrder() async {
    final last = await _isar.llmProviders
        .where()
        .sortBySortOrderDesc()
        .findFirstAsync();
    return (last?.sortOrder ?? -1) + 1;
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
