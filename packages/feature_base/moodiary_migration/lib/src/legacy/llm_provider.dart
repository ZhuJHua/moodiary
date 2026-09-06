// 字段顺序/形状即 isar 编码地址，改动会读坏旧库

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart'
    show AssistantProviderType;
import 'package:moodiary_utils/moodiary_utils.dart';

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

    required String defaultModel,

    required DateTime createdAt,

    required int sortOrder,

    @Default('') String presetId,

    @Default(<String>[]) List<String> models,

    @Default(false) bool toolCall,

    @Default(false) bool reasoning,

    @Default(false) bool attachment,
  }) = _LlmProvider;

  const LlmProvider._();

  factory LlmProvider.create({
    required String name,
    required AssistantProviderType type,
    required String baseUrl,
    required String defaultModel,
    required int sortOrder,
    String presetId = '',
    List<String> models = const [],
    bool toolCall = false,
    bool reasoning = false,
    bool attachment = false,
  }) {
    return LlmProvider(
      id: uuidV7(),
      name: name,
      type: type.id,
      baseUrl: baseUrl,
      defaultModel: defaultModel,
      createdAt: .timestamp(),
      sortOrder: sortOrder,
      presetId: presetId,
      models: models,
      toolCall: toolCall,
      reasoning: reasoning,
      attachment: attachment,
    );
  }

  factory LlmProvider.fromJson(Map<String, dynamic> json) =>
      _$LlmProviderFromJson(json);

  bool get isPreset => presetId.isNotEmpty;

  AssistantProviderType get protocol => .fromId(type);
}
