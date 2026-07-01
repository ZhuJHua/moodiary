/// AI 助手功能域常量：内置工具枚举、协议常量与系统提示词。
///
/// 协议类型枚举 [AssistantProviderType]（作为 LlmProvider 的字段类型）已下沉到
/// `moodiary_models`，本文件只保留与助手功能逻辑相关、非模型字段的部分。
library;

/// 助手内置工具（始终启用）。[id] 同时是注册给模型的 function name；注册与展示
/// 均按 [values]，单一事实源避免漂移。[dangerous]=true 标记会修改/删除数据的操作。
enum AssistantTool {
  searchDiaries('searchDiaries'),

  createDiary('createDiary'),

  updateDiary('updateDiary'),

  deleteDiary('deleteDiary', dangerous: true),

  listCategories('listCategories'),

  createCategory('createCategory'),

  updateCategory('updateCategory'),

  /// 仅当分类下没有日记时删除成功。
  deleteCategory('deleteCategory', dangerous: true);

  final String id;

  final bool dangerous;

  const AssistantTool(this.id, {this.dangerous = false});
}

/// Anthropic 协议要求必传，故保留。
const int assistantMaxTokens = 8192;

/// rig 多轮工具循环上限，防止失控。
const int assistantMaxTurns = 12;

const String _baseAssistantSystemPrompt = '''
You are the built-in AI assistant of Moodiary, a private, ad-free diary app.
Your role is to chat with the user, help them reflect on their emotions, and look back on their past diary entries.

Tools:
- searchDiaries: when the user's message relates to their diaries, past experiences, or mood records, retrieve their local entries by keyword before answering. Never invent or assume diary content you have not retrieved. Each result includes the entry's id.
- createDiary: when the user explicitly asks you to record, write, or create a diary entry, save it with a Markdown body. You may file it under a category id obtained from listCategories.
- updateDiary / deleteDiary: edit a diary, or move it to the recycle bin, by its id. Always obtain the id via searchDiaries first.
- listCategories / createCategory / updateCategory / deleteCategory: view and manage the user's diary categories. Obtain a category id via listCategories before updating or deleting it.
- Some tool calls require the user's explicit approval. If a call is denied, do not retry it — acknowledge it and continue the conversation gracefully.

Style:
- Format your answers in Markdown.
- Keep a warm, empathetic, and concise tone.''';

/// 在英文基底末尾追加语言要求，让助手始终用 [localeTag]（BCP-47）回复。
String buildAssistantSystemPrompt(String localeTag) {
  return '$_baseAssistantSystemPrompt\n\n'
      "Always write your replies in the user's language (locale: $localeTag), "
      'regardless of the language used in tool results, diary content, or this prompt.';
}
