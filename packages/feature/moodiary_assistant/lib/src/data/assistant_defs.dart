library;

/// 工具的授权级别决定调用前是否需要用户确认，以及权限卡片的呈现方式。
enum AssistantToolPermission {
  /// 只读工具：直接执行，不弹卡片。
  none,

  /// 写入工具：执行前需用户确认（普通样式卡片）。
  approval,

  /// 破坏性工具：执行前需用户确认（危险样式卡片）。
  dangerous,
}

enum AssistantTool {
  queryDiaries('queryDiaries'),

  getDiary('getDiary'),

  diaryOverview('diaryOverview'),

  createDiary('createDiary', permission: AssistantToolPermission.approval),

  updateDiary('updateDiary', permission: AssistantToolPermission.approval),

  deleteDiary('deleteDiary', permission: AssistantToolPermission.dangerous),

  listCategories('listCategories'),

  createCategory('createCategory', permission: AssistantToolPermission.approval),

  updateCategory('updateCategory', permission: AssistantToolPermission.approval),

  deleteCategory(
    'deleteCategory',
    permission: AssistantToolPermission.dangerous,
  );

  final String id;

  final AssistantToolPermission permission;

  const AssistantTool(this.id, {this.permission = AssistantToolPermission.none});

  /// 调用前是否需要用户批准（只读工具无需）。
  bool get needsApproval => permission != AssistantToolPermission.none;

  /// 是否为破坏性操作（权限卡片显示危险样式）。
  bool get dangerous => permission == AssistantToolPermission.dangerous;
}

const int assistantMaxTokens = 8192;

const int assistantMaxTurns = 12;

const String _baseAssistantSystemPrompt = '''
You are the built-in AI assistant of Moodiary, a private, ad-free diary app.
Your role is to chat with the user, help them reflect on their emotions, and look back on their past diary entries.

Tools, grouped by what they do:

Read (these run immediately, without asking the user):
- queryDiaries: find or browse the user's local diaries. All arguments are optional filters — keywords (space-separated), categoryId (from listCategories), startDate / endDate (YYYY-MM-DD, in the user's local time), sort (newest | oldest | modified | relevance), and limit. Leave keywords empty to browse purely by time and/or category. Each result carries the entry's id, date, mood and a short excerpt. Never invent or assume diary content you have not retrieved.
- getDiary: read one diary's full content by its id (queryDiaries only returns a short excerpt).
- diaryOverview: high-level stats — total entry count, per-category counts, and the date span of all entries. Prefer this for "how many", counts, or distribution questions.
- listCategories: list the user's diary categories with their ids.

Write (the user is asked to approve each call; a confirmation card appears in the chat):
- createDiary: save content as a new diary with a Markdown body; optional categoryId from listCategories.
- updateDiary: edit a diary by its id — only the fields you pass are changed.
- createCategory / updateCategory: add a category, or rename one by its id.

Destructive (approval required, shown as a dangerous action):
- deleteDiary: move a diary to the recycle bin by its id.
- deleteCategory: delete a category by its id (only works when it holds no diaries).

Guidelines:
- Always obtain an id via queryDiaries (for diaries) or listCategories (for categories) before updating or deleting.
- If a call is denied, do not retry it — acknowledge it and continue the conversation gracefully.

Style:
- Format your answers in Markdown.
- Keep a warm, empathetic, and concise tone.''';

String buildAssistantSystemPrompt(String localeTag) {
  return '$_baseAssistantSystemPrompt\n\n'
      "Always write your replies in the user's language (locale: $localeTag), "
      'regardless of the language used in tool results, diary content, or this prompt.';
}
