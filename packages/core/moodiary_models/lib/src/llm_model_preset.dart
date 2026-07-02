import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_model_preset.freezed.dart';
part 'llm_model_preset.g.dart';

@freezed
abstract class LlmModelPreset with _$LlmModelPreset {
  const factory LlmModelPreset({
    required String id,
    required String name,
    @Default(false) bool toolCall,
    @Default(false) bool reasoning,
    @Default(false) bool attachment,

    int? contextLimit,

    int? outputLimit,

    num? inputCost,

    num? outputCost,

    String? releaseDate,
  }) = _LlmModelPreset;

  const LlmModelPreset._();

  factory LlmModelPreset.fromJson(Map<String, dynamic> json) =>
      _$LlmModelPresetFromJson(json);

  static LlmModelPreset? fromModelsDev(String id, Map<String, dynamic> json) {
    final mid = (json['id'] as String?)?.trim().isNotEmpty == true
        ? (json['id'] as String).trim()
        : id.trim();
    if (mid.isEmpty) return null;

    final limit = json['limit'];
    final cost = json['cost'];
    return LlmModelPreset(
      id: mid,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : mid,
      toolCall: json['tool_call'] == true,
      reasoning: json['reasoning'] == true,
      attachment: json['attachment'] == true,
      contextLimit: limit is Map ? (limit['context'] as num?)?.toInt() : null,
      outputLimit: limit is Map ? (limit['output'] as num?)?.toInt() : null,
      inputCost: cost is Map ? cost['input'] as num? : null,
      outputCost: cost is Map ? cost['output'] as num? : null,
      releaseDate: (json['release_date'] as String?)?.trim(),
    );
  }
}
