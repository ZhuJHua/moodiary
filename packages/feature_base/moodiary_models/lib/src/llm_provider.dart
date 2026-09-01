import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'assistant_provider_type.dart';

part 'llm_provider.freezed.dart';
part 'llm_provider.g.dart';

/// 用户添加的一家供应商 —— **凭据 + 端点，不是一个模型**。模型是它下面的选择：
/// preset 供应商的模型来自 models.dev 目录，自定义供应商的来自 [models]。
///
/// ⚠️ [type] / [baseUrl] **只对自定义供应商生效**。preset 供应商的协议与 baseUrl
/// 是**按模型**从目录解析的 —— 中转站底下 Claude 走 messages、GPT 走 responses，
/// 同一家内部就分叉，存在供应商上必然发错。见 `LlmModelPreset.protocol/baseUrl`。
@freezed
abstract class LlmProvider with _$LlmProvider {
  const factory LlmProvider({
    required String id,

    required String name,

    /// 仅自定义供应商：[AssistantProviderType.id]。
    required String type,

    /// 仅自定义供应商：端点根地址。
    required String baseUrl,

    /// 新会话默认选中的模型 id。
    required String defaultModel,

    required DateTime createdAt,

    required int sortOrder,

    /// 这一条是从哪个 models.dev 预设建出来的（`LlmProviderPreset.id`，如 `deepseek`）。
    /// **自定义供应商恒为空串**，全仓靠 `isEmpty` 区分两类：空 = 不查在线目录、
    /// 不拉 logo、baseUrl 与协议可改。它不是键，重复不要紧 —— 身份是 [id]（uuid v7）。
    @Default('') String presetId,

    /// 仅自定义供应商：可选模型 id 列表（`GET {base}/models` 拉到的 + 手工补的）。
    /// 落库是为了让选择器离线可用 —— 每次开都联网拉一遍不可接受。
    @Default(<String>[]) List<String> models,

    /// 模型能力标记。preset 供应商以在线目录为准（逐模型），这里仅对**自定义**供应商
    /// 生效且对其下所有模型一视同仁。三者都默认 false（opt-in）。
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

  /// 是否是从 models.dev 预设建出来的（决定模型列表与协议从哪来）。
  bool get isPreset => presetId.isNotEmpty;

  /// 仅自定义供应商有意义。
  AssistantProviderType get protocol => .fromId(type);
}
