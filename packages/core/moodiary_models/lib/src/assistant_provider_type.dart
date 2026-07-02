enum AssistantProviderType {
  openai(id: 'openai'),
  anthropic(id: 'anthropic');

  final String id;

  const AssistantProviderType({required this.id});

  static AssistantProviderType fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => openai);

  static AssistantProviderType? fromNpm(String? npm) {
    if (npm == null) return null;
    const openaiAdapters = {'@ai-sdk/openai', '@ai-sdk/openai-compatible'};
    const anthropicAdapters = {'@ai-sdk/anthropic'};
    if (openaiAdapters.contains(npm)) return openai;
    if (anthropicAdapters.contains(npm)) return anthropic;
    return null;
  }
}
