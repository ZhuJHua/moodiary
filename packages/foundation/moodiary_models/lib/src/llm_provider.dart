import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'assistant_provider_type.dart';

part 'llm_provider.freezed.dart';
part 'llm_provider.g.dart';

/// 用户自定义的 LLM Provider 实例（可激活的服务商配置）。
/// **API Key 不存在这里**，而是放 SecureStorage，由 `LlmProviderRepository`
/// 按 `llm_key_<id>` 读写。
@freezed
@Collection(ignore: {'copyWith'})
abstract class LlmProvider with _$LlmProvider {
  const factory LlmProvider({
    @Id() required String id,

    required String name,

    /// 协议类型 id，取值见 [AssistantProviderType.id]（'openai' / 'anthropic'）。
    required String type,

    /// 自定义 baseUrl，留空表示使用该协议官方端点。
    required String baseUrl,

    required String model,

    required DateTime createdAt,

    /// 列表排序用，越小越靠前。
    required int sortOrder,
  }) = _LlmProvider;

  factory LlmProvider.create({
    required String name,
    required AssistantProviderType type,
    required String baseUrl,
    required String model,
    required int sortOrder,
  }) {
    return LlmProvider(
      id: uuidV7(),
      name: name,
      type: type.id,
      baseUrl: baseUrl,
      model: model,
      createdAt: DateTime.timestamp(),
      sortOrder: sortOrder,
    );
  }

  factory LlmProvider.fromJson(Map<String, dynamic> json) =>
      _$LlmProviderFromJson(json);
}

extension LlmProviderX on LlmProvider {
  /// 协议类型枚举。放在 extension 里，避免被 Isar 当作可持久化 getter。
  AssistantProviderType get protocol => AssistantProviderType.fromId(type);
}
