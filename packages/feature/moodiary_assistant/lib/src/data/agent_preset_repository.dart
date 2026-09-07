import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

@lazySingleton
class AgentPresetRepository {
  AgentPresetRepository(this._db);

  final MoodiaryDatabase _db;

  static AgentPreset _toPreset(AgentPresetRow r) => AgentPreset(
    id: r.id,
    name: r.name,
    description: r.description,
    persona: r.persona,
    // null（全部，含未来新增）与 '[]'（一个都不挂）语义不同，不能塌成空列表。
    tools: dbToStringListOrNull(r.toolsJson),
    createdAt: dbToTime(r.createdAt),
    updatedAt: dbToTime(r.updatedAt),
  );

  Future<List<AgentPreset>> getAll() async {
    final rows = await (_db.select(
      _db.agentPresets,
    )..orderBy([(p) => OrderingTerm.asc(p.createdAt)])).get();
    return [for (final r in rows) _toPreset(r)];
  }

  Future<AgentPreset?> get(String id) async {
    final row = await (_db.select(
      _db.agentPresets,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toPreset(row);
  }

  Future<void> put(AgentPreset preset) async {
    await _db
        .into(_db.agentPresets)
        .insertOnConflictUpdate(
          AgentPresetsCompanion.insert(
            id: preset.id,
            name: preset.name,
            description: Value(preset.description),
            persona: preset.persona,
            toolsJson: Value(dbStringListOrNull(preset.tools)),
            createdAt: dbTime(preset.createdAt),
            updatedAt: dbTime(preset.updatedAt),
          ),
        );
  }

  Future<bool> delete(String id) async {
    final removed = await (_db.delete(
      _db.agentPresets,
    )..where((p) => p.id.equals(id))).go();
    return removed > 0;
  }
}
