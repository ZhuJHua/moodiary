import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'assistant_provider_type.dart';

part 'llm_provider.freezed.dart';
part 'llm_provider.g.dart';

@freezed
@Collection(ignore: {'copyWith'})
abstract class LlmProvider with _$LlmProvider {
  const factory LlmProvider({
    @Id() required String id,

    required String name,

    required String type,

    required String baseUrl,

    required String model,

    required DateTime createdAt,

    required int sortOrder,

    @Default('') String providerId,

    /// 模型能力标记。preset 供应商以在线目录为准，这里仅对**自定义**供应商生效。
    /// 三者都默认 false（opt-in），由用户按模型实际能力逐个开启。
    @Default(false) bool toolCall,

    @Default(false) bool reasoning,

    @Default(false) bool attachment,
  }) = _LlmProvider;

  factory LlmProvider.create({
    required String name,
    required AssistantProviderType type,
    required String baseUrl,
    required String model,
    required int sortOrder,
    String providerId = '',
    bool toolCall = false,
    bool reasoning = false,
    bool attachment = false,
  }) {
    return LlmProvider(
      id: uuidV7(),
      name: name,
      type: type.id,
      baseUrl: baseUrl,
      model: model,
      createdAt: DateTime.timestamp(),
      sortOrder: sortOrder,
      providerId: providerId,
      toolCall: toolCall,
      reasoning: reasoning,
      attachment: attachment,
    );
  }

  factory LlmProvider.fromJson(Map<String, dynamic> json) =>
      _$LlmProviderFromJson(json);
}

extension LlmProviderX on LlmProvider {
  AssistantProviderType get protocol => AssistantProviderType.fromId(type);
}
