library;

enum AssistantTool {
  searchDiaries('searchDiaries'),

  createDiary('createDiary'),

  updateDiary('updateDiary'),

  deleteDiary('deleteDiary', dangerous: true),

  listCategories('listCategories'),

  createCategory('createCategory'),

  updateCategory('updateCategory'),

  deleteCategory('deleteCategory', dangerous: true);

  final String id;

  final bool dangerous;

  const AssistantTool(this.id, {this.dangerous = false});
}

const int assistantMaxTokens = 8192;

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

String buildAssistantSystemPrompt(String localeTag) {
  return '$_baseAssistantSystemPrompt\n\n'
      "Always write your replies in the user's language (locale: $localeTag), "
      'regardless of the language used in tool results, diary content, or this prompt.';
}
