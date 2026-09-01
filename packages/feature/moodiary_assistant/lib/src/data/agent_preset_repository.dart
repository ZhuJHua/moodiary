import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 用户自建助手预设（[AgentPreset]）的读写。仅设备本地：不进备份、不进同步。
///
/// 只管落库的用户行；内置预设「Moodiary助手」是虚拟的（persona 常量 + l10n 名称），
/// 由 assistant feature 侧合成 roster——data 层不该认识提示词文本与文案。
class AgentPresetRepository {
  AgentPresetRepository._(this._db);

  factory AgentPresetRepository.get() => _instance;

  @visibleForTesting
  AgentPresetRepository.forTesting(this._db);

  static final AgentPresetRepository _instance = ._(MoodiaryDatabase.get());

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

  /// 全部用户预设，按创建时间正序（roster 顺序稳定，新派生的排最后）。
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
