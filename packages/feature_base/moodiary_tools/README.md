# moodiary_tools

Diary use cases and structured tools shared by the assistant and MCP adapters.
`moodiaryTools` describes each tool, its surfaces, effects, schemas and typed
parser/executor. Call a definition with a `ToolContext`; invalid arguments throw
`ToolArgumentException`, domain failures throw `ToolFailure`, and successful
`ToolResult`s contain JSON data, optional media and diary references.

The catalog uses `ToolDefinition` to hold definitions with different input types.
`ToolDef<I, O>` exposes the typed parser, executor and JSON serializer. Context
provides repositories, media storage, the calling surface, optional semantic
indexing and progress. The barrel also exports diary/category/statistics use
cases and the query and payload helpers used by MCP prompts.

Both surfaces share the same batched read and write contracts. The shared argument
validator preserves optional nulls, trimmed enum values, mood aliases and numeric
clamping: it validates a compatible projection and leaves clamping to the typed
parsers. A standalone `ToolDef` validates its input schema directly unless a
validator is supplied. Output schemas are advertised but not validated at runtime.

`search_diaries` also browses when `query` is omitted, with paging, category,
exact tag, local inclusive dates, sort and excerpt filters. The assistant adds
`mode` for keyword/semantic fusion; MCP is keyword-only. `get_diary` accepts
`ids` (1–10) and returns `diaries` and `missing`. Bodies are Markdown with media
references preserved. Assistant bodies are capped at 4000 characters and report
`truncated` and `fullLength`; MCP also supports text/document and link options.

Diary and category creates/updates accept `items` (1–20); deletes accept `ids`
(1–20). Results are `{results: [{ok, id?, error?, ...payload}], processed,
requested}`. Semantic per-item failures do not stop later items; a call-wide
schema failure executes nothing. Omitted update fields stay unchanged; explicit
null clears nullable fields. `diaryIdsIn` extracts citations from stored JSON,
including successful batch rows, without needing the original arguments.

`get_diary_links`, `list_tags`, `list_categories` and `get_stats` are shared.
The four media tools are MCP-only. The assistant owns `recall_memory`,
`remember_fact`, `forget_fact` and `run_javascript` in its own package.
