import 'package:freezed_annotation/freezed_annotation.dart';

import 'assistant_provider_type.dart';
import 'reasoning_control.dart';

part 'llm_model_preset.freezed.dart';
part 'llm_model_preset.g.dart';

@freezed
abstract class LlmModelPreset with _$LlmModelPreset {
  const factory LlmModelPreset({
    required String id,
    required String name,

    required AssistantProviderType protocol,

    required String baseUrl,

    @Default('') String description,

    @Default(false) bool toolCall,
    @Default(false) bool reasoning,
    bool? structuredOutput,

    bool? temperature,

    List<ReasoningControl>? reasoningOptions,

    String? interleavedField,

    int? contextLimit,

    int? inputLimit,

    int? outputLimit,

    @Default(<String>[]) List<String> inputModalities,

    num? inputCost,
    num? outputCost,
    num? reasoningCost,
    num? cacheReadCost,
    num? cacheWriteCost,

    String? releaseDate,

    String? status,
  }) = _LlmModelPreset;

  const LlmModelPreset._();

  factory LlmModelPreset.fromJson(Map<String, dynamic> json) =>
      _$LlmModelPresetFromJson(json);

  bool get deprecated => status == 'deprecated';

  bool get acceptsImage => inputModalities.contains('image');

  static LlmModelPreset? fromModelsDev(
    String id,
    Map<String, dynamic> json, {
    required AssistantProviderType protocol,
    required String baseUrl,
  }) {
    final mid = _trimOr(json['id'], id);
    if (mid.isEmpty) return null;

    final limit = json['limit'];
    final cost = json['cost'];
    final interleaved = json['interleaved'];
    final rawOptions = json['reasoning_options'];

    return LlmModelPreset(
      id: mid,
      name: _trimOr(json['name'], mid),
      protocol: protocol,
      baseUrl: baseUrl,
      description: _trimOr(json['description'], ''),
      toolCall: json['tool_call'] == true,
      reasoning: json['reasoning'] == true,
      structuredOutput: json['structured_output'] as bool?,
      temperature: json['temperature'] as bool?,
      reasoningOptions: rawOptions is List
          ? [
              for (final o in rawOptions)
                if (o is Map)
                  ?ReasoningControl.fromModelsDev(o.cast<String, dynamic>()),
            ]
          : null,
      interleavedField: interleaved is Map
          ? _trimToNull(interleaved['field'])
          : null,
      contextLimit: _int(limit, 'context'),
      inputLimit: _int(limit, 'input'),
      outputLimit: _int(limit, 'output'),
      inputModalities: _strings(json['modalities'], 'input'),
      inputCost: _num(cost, 'input'),
      outputCost: _num(cost, 'output'),
      reasoningCost: _num(cost, 'reasoning'),
      cacheReadCost: _num(cost, 'cache_read'),
      cacheWriteCost: _num(cost, 'cache_write'),
      releaseDate: _trimToNull(json['release_date']),
      status: _trimToNull(json['status']),
    );
  }
}

int? _int(Object? table, String key) =>
    table is Map ? (table[key] as num?)?.toInt() : null;

num? _num(Object? table, String key) =>
    table is Map ? table[key] as num? : null;

List<String> _strings(Object? table, String key) {
  if (table is! Map) return const [];
  final v = table[key];
  return v is List ? v.whereType<String>().toList() : const [];
}

String _trimOr(Object? v, String fallback) {
  final t = v is String ? v.trim() : '';
  return t.isEmpty ? fallback : t;
}

String? _trimToNull(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}
