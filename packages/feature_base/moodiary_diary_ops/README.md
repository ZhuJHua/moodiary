# moodiary_diary_ops

Diary, category and statistics use cases shared by the two tool surfaces of the
app:

- the in-app assistant (`moodiary_assistant`), which renders its tools as text
  for a model, and
- the local MCP server (`moodiary_mcp`), which renders the same domain as JSON
  for external clients.

The package owns **business rules**, not protocol:

| Here | In the client |
| --- | --- |
| search (keyword, semantic, fusion), paging, batch reads | tool names, descriptions, JSON schemas |
| create / patch / recycle / permanent delete | model-facing text and JSON encoding |
| content conversion (Markdown→Tiptap vs plain text) and media re-derivation | batch vs single-call semantics |
| category tree, parent validation, cycle rejection | approval tiers (assistant) |
| statistics payloads and the Markdown/Tiptap projections | transport, registry, resources, prompts |

Callers pass the content codec, the index mode, the delete mode and the
validation strictness explicitly, because those are product decisions that
differ between the two surfaces. The package never touches `getIt`: the caller
constructs it with the repositories it already has.

## Rules

- Keep model-facing text (assistant) and JSON shapes (MCP) in their clients.
  Moving them here would change the assistant's prompt cache prefix and its
  tool-output contract.
- A new shared operation returns domain objects or typed records and reports
  failures through `DiaryOpsException` with a `DiaryOpsFailure` code; each
  client maps the code to its own error surface.
- The assistant's batch loop and its `Failed:` conventions stay in the
  assistant; MCP's `Args` validation and `McpToolResult` stay in the server.
