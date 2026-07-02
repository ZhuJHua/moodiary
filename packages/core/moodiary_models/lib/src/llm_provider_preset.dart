import 'package:freezed_annotation/freezed_annotation.dart';
import 'assistant_provider_type.dart';
import 'llm_model_preset.dart';

part 'llm_provider_preset.freezed.dart';
part 'llm_provider_preset.g.dart';

@freezed
abstract class LlmProviderPreset with _$LlmProviderPreset {
  const factory LlmProviderPreset({
    required String id,
    required String name,

    required AssistantProviderType protocol,

    required String baseUrl,
    required List<LlmModelPreset> models,

    String? docUrl,

    @Default(<String>[]) List<String> env,

    String? logoUrl,
  }) = _LlmProviderPreset;

  const LlmProviderPreset._();

  factory LlmProviderPreset.fromJson(Map<String, dynamic> json) =>
      _$LlmProviderPresetFromJson(json);

  static LlmProviderPreset? fromModelsDev(
    String id,
    Map<String, dynamic> json,
  ) {
    final pid = (json['id'] as String?)?.trim().isNotEmpty == true
        ? (json['id'] as String).trim()
        : id.trim();
    if (pid.isEmpty) return null;

    final protocol = AssistantProviderType.fromNpm(json['npm'] as String?);
    if (protocol == null) return null;

    final rawModels = json['models'];
    final models = <LlmModelPreset>[];
    if (rawModels is Map) {
      rawModels.forEach((k, v) {
        if (k is String && v is Map) {
          final m = LlmModelPreset.fromModelsDev(k, v.cast<String, dynamic>());
          if (m != null) models.add(m);
        }
      });
    }
    if (models.isEmpty) return null;

    models.sort((a, b) {
      if (a.toolCall != b.toolCall) return a.toolCall ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final env = <String>[];
    final rawEnv = json['env'];
    if (rawEnv is List) {
      env.addAll(rawEnv.whereType<String>());
    }

    return LlmProviderPreset(
      id: pid,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : pid,
      protocol: protocol,
      baseUrl: (json['api'] as String?)?.trim() ?? '',
      docUrl: _trimToNull(json['doc']),
      env: env,
      logoUrl: 'https://models.dev/logos/$pid.svg',
      models: models,
    );
  }
}

String? _trimToNull(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}
