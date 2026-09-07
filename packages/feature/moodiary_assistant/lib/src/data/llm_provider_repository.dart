import 'dart:async';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

@lazySingleton
class LlmProviderRepository {
  LlmProviderRepository(this._db, this._secure);

  final MoodiaryDatabase _db;
  final ISecureKVStorage _secure;

  static String _keyOf(String id) => 'llm_key_$id';

  final StreamController<void> _events = StreamController<void>.broadcast();

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

  Future<void> deleteProvider(String id) async {
    await (_db.delete(_db.llmProviders)..where((p) => p.id.equals(id))).go();
    await removeKey(id);
    if (MoodiaryKVs.assistantActiveProviderId.get() == id) {
      MoodiaryKVs.assistantActiveProviderId.set('');
    }
    _events.add(null);
  }

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

  Future<int> nextSortOrder() async {
    final maxOrder = _db.llmProviders.sortOrder.max();
    final row = await (_db.selectOnly(
      _db.llmProviders,
    )..addColumns([maxOrder])).getSingle();
    return (row.read(maxOrder) ?? -1) + 1;
  }

  Future<String?> getKey(String id) => _secure.get(_keyOf(id));

  Future<void> setKey(String id, String value) =>
      _secure.set(_keyOf(id), value);

  Future<void> removeKey(String id) => _secure.remove(_keyOf(id));

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
