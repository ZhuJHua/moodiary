/// 助手支持的 LLM 协议类型；[LlmProvider] 绑定其一（作为字段类型），决定 rig 侧走哪套
/// 协议。属领域模型层；助手工具枚举 / 系统提示词等功能逻辑留在 app 层 `core/values/assistant.dart`。
enum AssistantProviderType {
  openai(
    id: 'openai',
    label: 'OpenAI 兼容',
    presetModels: [
      'gpt-4o',
      'gpt-4o-mini',
      'gpt-4.1',
      'gpt-4.1-mini',
      'o4-mini',
    ],
  ),
  anthropic(
    id: 'anthropic',
    label: 'Anthropic 兼容',
    presetModels: [
      'claude-sonnet-4-5',
      'claude-opus-4-1',
      'claude-3-7-sonnet-latest',
      'claude-3-5-haiku-latest',
    ],
  );

  /// 与持久化字符串一致的稳定标识（存于 [LlmProvider.type]）。
  final String id;

  final String label;

  /// 编辑页下拉的预置模型，仍允许手动输入其它模型名。
  final List<String> presetModels;

  const AssistantProviderType({
    required this.id,
    required this.label,
    required this.presetModels,
  });

  String get defaultModel => presetModels.first;

  static AssistantProviderType fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => openai);
}
