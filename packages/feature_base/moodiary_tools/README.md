# moodiary_tools

Diary operations and structured tools shared by the assistant and MCP.
Tools and their schemas live in `lib/src/tools/`; `toolsFor` selects a surface.
`ToolDef` validates inputs and returns a `ToolResult` using `ToolContext` capabilities.
