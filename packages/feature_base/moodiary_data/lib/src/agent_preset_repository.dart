import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

/// 用户自建助手预设（[AgentPreset]）的读写。仅设备本地：不进备份、不进同步。
///
/// 只管落库的用户行；内置预设「Moodiary助手」是虚拟的（persona 常量 + l10n 名称），
/// 由 assistant feature 侧合成 roster——data 层不该认识提示词文本与文案。
class AgentPresetRepository {
  AgentPresetRepository._(this._isar);

  factory AgentPresetRepository.get() => _instance;

  static final AgentPresetRepository _instance = ._(IsarDatabase.get().isar);

  final Isar _isar;

  /// 全部用户预设，按创建时间正序（roster 顺序稳定，新派生的排最后）。
  Future<List<AgentPreset>> getAll() {
    return _isar.agentPresets.where().sortByCreatedAt().findAllAsync();
  }

  Future<AgentPreset?> get(String id) => _isar.agentPresets.getAsync(id);

  Future<void> put(AgentPreset preset) async {
    await _isar.writeAsync((isar) {
      isar.agentPresets.put(preset);
    });
  }

  Future<bool> delete(String id) {
    return _isar.writeAsync((isar) {
      return isar.agentPresets.delete(id);
    });
  }
}
