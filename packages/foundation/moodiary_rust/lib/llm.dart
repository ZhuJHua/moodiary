/// llm 门面：rig 的流式多轮对话 + 工具调用。只给 `moodiary_assistant`。
///
/// 调用 [rigChatStream] 前先 `await MoodiaryRust.ensureInitialized()`。
library;

export 'src/runtime.dart';
export 'src/rust/api/llm.dart';
