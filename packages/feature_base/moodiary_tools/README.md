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

Published input schemas retain the existing MCP contract. The shared argument
validator preserves optional nulls, trimmed enum values, mood aliases and numeric
clamping: it validates a compatible projection and leaves clamping to the typed
parsers. A standalone `ToolDef` validates its input schema directly unless a
validator is supplied. Output schemas are advertised but not validated at runtime.
