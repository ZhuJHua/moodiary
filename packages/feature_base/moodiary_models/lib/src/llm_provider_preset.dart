import 'package:freezed_annotation/freezed_annotation.dart';

import 'assistant_provider_type.dart';
import 'llm_model_preset.dart';

part 'llm_provider_preset.freezed.dart';
part 'llm_provider_preset.g.dart';

/// models.dev 的 npm 里，**端点可直连**的那几个。这不是我们拍的名单 ——
/// 它抄自目录自己的校验规则（`packages/core/src/schema.ts` 的 Provider refine）：
/// 这几个 npm 允许（或要求）带 `api` 字段，其余一律禁止带 `api`，也就是说
/// 目录压根没有可直连的端点可给。
const _openAiShapeNpm = {
  '@ai-sdk/openai',
  '@ai-sdk/openai-compatible',
  '@openrouter/ai-sdk-provider',
  'merge-gateway-ai-sdk-provider',
  'kiro-acp-ai-provider',
};

const _anthropicShapeNpm = {'@ai-sdk/anthropic'};

/// `api` 在 schema 里可以缺省的那几个 npm —— SDK 自己知道官方端点，所以
/// **只有这些供应商**的 baseUrl 允许为空（openai / anthropic 官方就是这样）。
///
/// 其余供应商解析不出 baseUrl 就是「不知道往哪发」，必须整条丢弃：留空会让 rig
/// 回落到官方端点，等于把用户的第三方 key 发去 api.anthropic.com。目录里真有这么
/// 一条 —— cloudflare-ai-gateway 的 Claude 把 npm 覆盖成了 anthropic 却没给 api。
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
        // 路由按模型解析：模型级 `provider` 块可以改写 npm / api / shape。
        final override = raw['provider'];
        final route = _resolveRoute(
          npm: override is Map ? _trimOr(override['npm'], npm) : npm,
          api: override is Map ? _trimOr(override['api'], baseUrl) : baseUrl,
          shape: override is Map ? _trimToNull(override['shape']) : null,
          allowsEmptyBaseUrl: _officialEndpointNpm.contains(npm),
        );
        // 协议解析不出来的模型直接剔掉，别让用户选中一个必然失败的条目。
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

/// npm + shape → 协议与 baseUrl。返回 null 表示这条线路我们接不了。
///
/// **默认一律 completions**：responses 只在目录显式标了 `shape = "responses"`
/// 时才走。`@ai-sdk/openai` 在 AI SDK 5 里默认是 responses，但顶着这个 npm 的
/// 4 家里只有 openai 官方确定支持，其余 3 家目录没有依据 —— 猜错的代价
/// （用户配好了发不出去）比少用一个新 API 大得多，所以这里保守。
({AssistantProviderType protocol, String baseUrl})? _resolveRoute({
  required String npm,
  required String api,
  required String? shape,
  required bool allowsEmptyBaseUrl,
}) {
  final baseUrl = _normalizeBaseUrl(api);
  if (baseUrl.isEmpty && !allowsEmptyBaseUrl) return null;
  // 目录对要账号信息的端点写成 `https://${AWS_REGION}...` 这种模板
  // （cloudflare-workers-ai / infomaniak / snowflake-cortex / databricks / neon）。
  // preset 供应商的 baseUrl 是按模型解析的、页面上不露出，用户没有地方替换占位符 ——
  // 与其留一个必然发不出去的配置，不如整条剔掉，需要的人走自定义供应商。
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

/// 目录里偶有把完整端点写进 `api` 的（bailing 是唯一一处），拼接时会变成
/// `.../chat/completions/chat/completions` —— rig 只在 anthropic 侧归一 baseUrl，
/// openai 侧是裸拼接。
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
