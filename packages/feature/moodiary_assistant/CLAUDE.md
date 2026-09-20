# moodiary_assistant: agent architecture and conventions

Dart orchestrates, Rust executes. rig (`rig-core` + `rig-agent`, pinned `=0.42.0`) only adapts the provider protocol and runs the tool loop; every architectural decision — prompt layering, memory, retrieval, the permission gate — lives here. Do not track rig's `main`; migrate to 0.43 in its own PR from MIGRATING.md.

## One request

`assistant_page._generate` builds an `AssistantChatRequest`; `RigAssistantService` turns it into an FRB `rig_chat_stream` call; `moodiary_rust/llm/chat.rs` builds the agent, registers one `AgentHook` (`ToolObserver`) and drives the stream back as `RigStreamEvent`s.

- **System prompt** (`buildStableSystemPrompt`) is ordered sections in one order band: `-100` identity, `-50` guardrails, `-25` retrieval policy (tools only, ≤150 words, test-pinned; one variant with memory on, one telling the model memory is off), `0` the built-in persona (a diary-and-notes companion, not diary-only: drafting, organizing and everyday questions are in scope), `25` the user's notes (`assistantUserNotes`, ≤2000 chars, omitted when empty), `100` tool catalog. Only the notes are user-editable: no presets, no custom persona, no per-session tool whitelist. Same inputs must give the same bytes — this is the provider cache prefix. The guardrails' tool sentence is chosen by the permission mode, so each mode has its own stable prefix.
- **Turn context** (`buildTurnContext`) carries only volatile, count-only data: local time, `Saved facts: N`, semantic search on/off. No language rule — the model answers in whatever language the user writes. On the OpenAI paths it is a `system` message before the last user message; on Anthropic it is glued onto the last user message.
- **History**: adjacent same-role messages merge; an assistant turn is prefixed with `[tools already run]` (only `recallMemory` replays its raw result, capped at 600 chars); a user turn's `[diary:id]` / `[continue]` marker is swapped for its English instruction on the way to the model and for l10n text in the UI. Text for the model is hardcoded English and never enters slang.
- **Events**: `Turn` is emitted per completion call (rig's `CompletionCall`) with `finish_reason`, ids and usage; the `Usage` at `FinalResponse` is the run's aggregate. Context length is the last `Turn`'s `input_tokens` — never the aggregate. `finish_reason == length` marks the reply truncated and offers Continue.

## Memory: opt-in and on demand only

`assistantMemoryEnabled` (KV, default on) gates the three memory tools. Off: they are not advertised (`toolIdsWithoutMemory`), the retrieval policy says so, the turn context carries no fact count. On: every fact is reached through `recallMemory`, nothing is injected into the prompt.

Standing preferences belong in the user's notes, written by the user. Diary text never enters `memories`; facts never enter the vector index.

## Personalisation

Settings › Personalisation holds exactly two things: the notes (`AssistantNotesPage`) and the memory switch (which also gates the memory page). There are no presets: the assistant is this app's companion, not a general agent.

## Tools

14 batch tools in `AssistantToolRegistry`. `searchDiaries` fuses FTS5 keyword and sqlite-vec semantic hits with reciprocal-rank fusion and returns excerpts; full text via `getDiary`.

Tool calls persisted under old ids (`queryDiaries`, `semanticSearchDiaries`, `listMemories`, `updateMemory`) are renamed on read by `ChatRepository` through `renamedAssistantToolIds`; every rename needs a mapping entry.

Every tool must follow the UI's own write paths: soft-delete = `show: false`, content changes re-extract media, invalid category ids fail instead of clearing.

## Permission gate

Tiers are decided per call from its arguments (`assistantToolTier`): read; reversible write; irreversible — `updateDiary` with `content` (overwrites text, no history), `deleteCategory`, `forgetFact`. `deleteDiary` is reversible because it goes to the recycle bin. Three modes (`AssistantPermissionMode`, KV `assistantPermissionMode`, session override in the page): `confirm` asks for every write, `auto` asks only for irreversible calls, `full` never asks.

The decision is Dart's but the pause is rig's: `ToolObserver.on_tool_call` emits `ToolStarted`, then awaits the Dart `toolGate`. Only the exact verdict `run` runs the tool; anything else (a `skip:` reason, a bridge error) becomes `ToolCallAction::Skip`, so the tool body never runs and the model reads `Skipped: …`.

`ToolApprovalGate` keeps one `Completer` per call id; stop, dispose and a 5-minute timeout all resolve as declined. rig's tool batch is sequential, so at most one card is ever pending; do not enable `tool_concurrency` while the gate exists. The card sits above the composer on the same glass surface, button radius `MuiRadius.inside(xl, 8)`; typing a reply while a card is pending declines it and queues the text for after the run.

## Invalid tool names and errors

`on_invalid_tool_call` normalises the emitted name (strips `default_api.` / `functions.` prefixes, case-insensitive) against the turn's allowed tools and repairs it without a model call; otherwise it asks for a retry with feedback and emits `TurnDiscarded` so the page drops that turn's deltas — rig's `max_invalid_tool_call_retries(1)` is the only budget.

Run errors cross the bridge as `<code>: <message>` (`max_turns`, `cancelled`, `unknown_tool`, `completion`); Dart maps the code to l10n and never matches English text.

## Deliberately not used

`dynamic_context`, `ConversationMemory` / `rig-memory` / `rig-sqlite`, `extractor` / `OutputMode`, `retrieved_tools`, `tool_concurrency`, `on_completion_response`, automatic max-tokens retry, `tracing`, `rig-ecs`, a code-level router in front of the model, tool or step caps sized for on-device models.
