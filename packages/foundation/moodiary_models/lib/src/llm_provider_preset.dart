import 'package:freezed_annotation/freezed_annotation.dart';
import 'assistant_provider_type.dart';

part 'llm_provider_preset.freezed.dart';

/// 远端预定义供应商（来自 `moodiary-llm-provider` 仓库的 index.json）。
/// 只读「模板」，用于「选择供应商」页预填编辑表单；与用户保存的 [LlmProvider] 无关。
@freezed
abstract class LlmProviderPreset with _$LlmProviderPreset {
  const factory LlmProviderPreset({
    required String id,
    required AssistantProviderType protocol,

    /// localeCode -> 展示名，必含 `default`。
    required Map<String, String> name,
    required String baseUrl,
    required List<String> models,
    String? apiKeyUrl,
    String? icon,
  }) = _LlmProviderPreset;

  const LlmProviderPreset._();

  /// 按界面语言取名，回退到 `default` / 任意一项 / id。
  String localizedName(String langCode) {
    return name[langCode] ??
        name['default'] ??
        (name.isNotEmpty ? name.values.first : id);
  }

  /// 缺 id / models 视为非法返回 null（调用方跳过）。
  static LlmProviderPreset? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final models =
        (json['models'] as List?)?.whereType<String>().toList() ?? const [];
    if (id.isEmpty || models.isEmpty) return null;

    final name = <String, String>{};
    final rawName = json['name'];
    if (rawName is Map) {
      rawName.forEach((k, v) {
        if (k is String && v is String) name[k] = v;
      });
    } else if (rawName is String) {
      name['default'] = rawName;
    }
    if ((name['default'] ?? '').isEmpty) name['default'] = id;

    return LlmProviderPreset(
      id: id,
      protocol: AssistantProviderType.fromId(json['protocol'] as String?),
      name: name,
      baseUrl: (json['baseUrl'] as String?)?.trim() ?? '',
      apiKeyUrl: _trimToNull(json['apiKeyUrl']),
      icon: _trimToNull(json['icon']),
      models: models,
    );
  }
}

String? _trimToNull(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}
