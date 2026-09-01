/// 助手支持的三种线路协议。**这是「请求长什么样」而不是「哪一家供应商」** ——
/// 同一家网关的不同模型可以走不同协议（models.dev 的模型级 `provider` 覆盖块就是干这个的）。
enum AssistantProviderType {
  /// `POST {base}/chat/completions`。兼容面最广，是一切未知端点的安全默认。
  openaiCompletions(id: 'openai-completions'),

  /// `POST {base}/responses`。OpenAI 官方与少数网关支持，能拿到推理摘要。
  openaiResponses(id: 'openai-responses'),

  /// `POST {base}/v1/messages`。
  anthropicMessages(id: 'anthropic-messages');

  final String id;

  const AssistantProviderType({required this.id});

  static AssistantProviderType fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => openaiCompletions);

  bool get isAnthropic => this == anthropicMessages;
}
