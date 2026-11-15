# moodiary_diary_ops

Shared diary operations for the in-app assistant and the local MCP server:
queries and search, diary writes and content conversion, categories and
validation, and aggregate summaries.

Callers supply repositories and choose content, indexing, deletion and
validation policies. Body edits re-derive media references and update
`lastModified`; category writes reject deletion of non-empty
categories. Failures use `DiaryOpsException` and `DiaryOpsFailure`.

Tool schemas, protocol payloads, model-facing text and approval handling stay
in the callers. This package does not use `getIt`.
