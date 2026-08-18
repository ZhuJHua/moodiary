import 'package:freezed_annotation/freezed_annotation.dart';

import 'assistant_provider_type.dart';
import 'reasoning_control.dart';

part 'llm_model_preset.freezed.dart';
part 'llm_model_preset.g.dart';

/// models.dev 的模型条目。**线路（协议 + baseUrl）在解析时就定下来了**：
/// 目录的路由覆盖是模型级的，同一家网关的 Claude 走 messages、GPT 走 responses、
/// 其余走 chat completions，所以这两项属于模型而不属于供应商。
@freezed
abstract class LlmModelPreset with _$LlmModelPreset {
  const factory LlmModelPreset({
    required String id,
    required String name,

    /// 这一款模型实际要走的协议。
    required AssistantProviderType protocol,

    /// 这一款模型实际要打的 baseUrl。空串表示走该协议官方端点。
    required String baseUrl,

    @Default('') String description,

    @Default(false) bool toolCall,
    @Default(false) bool reasoning,
    bool? structuredOutput,

    /// 温度是否可调（gpt-5 一类是 false）。
    bool? temperature,

    /// 思考控制能力。null = 目录没标；空列表 = 模型会思考但调用方无控制。
    List<ReasoningControl>? reasoningOptions,

    /// 交错思考的回传字段名（`reasoning_content` / `reasoning_details`）。
    String? interleavedField,

    int? contextLimit,

    /// 最大输入 token。与 [contextLimit] 不是一回事：后者含输出。
    int? inputLimit,

    int? outputLimit,

    @Default(<String>[]) List<String> inputModalities,

    num? inputCost,
    num? outputCost,
    num? reasoningCost,
    num? cacheReadCost,
    num? cacheWriteCost,

    String? releaseDate,

    /// `alpha` / `beta` / `deprecated`。null 表示正常在服。
    String? status,
  }) = _LlmModelPreset;

  const LlmModelPreset._();

  factory LlmModelPreset.fromJson(Map<String, dynamic> json) =>
      _$LlmModelPresetFromJson(json);

  /// 已下线的模型仍留在目录里，选择器该把它们折叠起来。
  bool get deprecated => status == 'deprecated';

  /// 能不能收图。目录给的 `modalities` 比那个粗粒度的 `attachment` bool 准
  /// —— 两者在 369 个模型上并不一致，且 modalities 全量都有。
  bool get acceptsImage => inputModalities.contains('image');

  /// [protocol] / [baseUrl] 由调用方按供应商与模型级覆盖解析后传入。
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

num? _num(Object? table, String key) => table is Map ? table[key] as num? : null;

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
