/// 快速 LLM 对话：rig 的流式多轮 + 工具调用，原生侧是自带的 `libfastllm`，
/// 经 flutter_rust_bridge 调用。
///
/// 用法：调用 [rigChatStream] 前先 `await FastLlm.ensureInitialized()`。
library;

export 'src/runtime.dart';
export 'src/rust/api/assistant.dart';
export 'src/rust/frb_generated.dart' show FastLlmLib;
