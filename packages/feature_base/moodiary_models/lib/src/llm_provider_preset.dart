import 'package:freezed_annotation/freezed_annotation.dart';

import 'assistant_provider_type.dart';
import 'llm_model_preset.dart';

part 'llm_provider_preset.freezed.dart';
part 'llm_provider_preset.g.dart';

const _openAiShapeNpm = {
  '@ai-sdk/openai',
  '@ai-sdk/openai-compatible',
  '@openrouter/ai-sdk-provider',
  'merge-gateway-ai-sdk-provider',
  'kiro-acp-ai-provider',
};

const _anthropicShapeNpm = {'@ai-sdk/anthropic'};

const _officialEndpointNpm = {
  '@ai-sdk/openai',
  '@ai-sdk/anthropic',
  'kiro-acp-ai-provider',
};

@freezed
abstract class LlmProviderPreset with _$LlmProviderPreset {
  const factory LlmProviderPreset({
    required String id,
    required String name,
    required List<LlmModelPreset> models,

    String? docUrl,

    @Default(<String>[]) List<String> env,

    String? logoUrl,
  }) = _LlmProviderPreset;

  factory LlmProviderPreset.fromJson(Map<String, dynamic> json) =>
      _$LlmProviderPresetFromJson(json);

  static LlmProviderPreset? fromModelsDev(
    String id,
    Map<String, dynamic> json,
  ) {
    final pid = _trimOr(json['id'], id.trim());
    if (pid.isEmpty) return null;

    final npm = _trimToNull(json['npm']);
    if (npm == null) return null;
    final baseUrl = _normalizeBaseUrl(_trimOr(json['api'], ''));

    final models = <LlmModelPreset>[];
    final rawModels = json['models'];
    if (rawModels is Map) {
      rawModels.forEach((k, v) {
        if (k is! String || v is! Map) return;
        final raw = v.cast<String, dynamic>();
        final override = raw['provider'];
        final route = _resolveRoute(
          npm: override is Map ? _trimOr(override['npm'], npm) : npm,
          api: override is Map ? _trimOr(override['api'], baseUrl) : baseUrl,
          shape: override is Map ? _trimToNull(override['shape']) : null,
          allowsEmptyBaseUrl: _officialEndpointNpm.contains(npm),
        );
        if (route == null) return;
        final m = LlmModelPreset.fromModelsDev(
          k,
          raw,
          protocol: route.protocol,
          baseUrl: route.baseUrl,
        );
        if (m != null) models.add(m);
      });
    }
    if (models.isEmpty) return null;

    models.sort((a, b) {
      if (a.deprecated != b.deprecated) return a.deprecated ? 1 : -1;
      if (a.toolCall != b.toolCall) return a.toolCall ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return LlmProviderPreset(
      id: pid,
      name: _trimOr(json['name'], pid),
      docUrl: _trimToNull(json['doc']),
      env: switch (json['env']) {
        final List raw => raw.whereType<String>().toList(),
        _ => const <String>[],
      },
      logoUrl: 'https://models.dev/logos/$pid.svg',
      models: models,
    );
  }
}

({AssistantProviderType protocol, String baseUrl})? _resolveRoute({
  required String npm,
  required String api,
  required String? shape,
  required bool allowsEmptyBaseUrl,
}) {
  final baseUrl = _normalizeBaseUrl(api);
  if (baseUrl.isEmpty && !allowsEmptyBaseUrl) return null;
  if (baseUrl.contains(r'${')) return null;
  if (_anthropicShapeNpm.contains(npm)) {
    return (protocol: .anthropicMessages, baseUrl: baseUrl);
  }
  if (!_openAiShapeNpm.contains(npm)) return null;
  return (
    protocol: shape == 'responses' ? .openaiResponses : .openaiCompletions,
    baseUrl: baseUrl,
  );
}

String _normalizeBaseUrl(String raw) {
  var url = raw.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  const suffix = '/chat/completions';
  return url.endsWith(suffix)
      ? url.substring(0, url.length - suffix.length)
      : url;
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
