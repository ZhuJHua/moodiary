enum AssistantProviderType {
  openaiCompletions(id: 'openai-completions'),

  openaiResponses(id: 'openai-responses'),

  anthropicMessages(id: 'anthropic-messages');

  final String id;

  const AssistantProviderType({required this.id});

  static AssistantProviderType fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => openaiCompletions);

  bool get isAnthropic => this == anthropicMessages;
}
