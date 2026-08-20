/// 助手能力：rig 的多轮对话流，以及给模型算数用的 QuickJS 沙箱。
///
/// **只有 `moodiary_assistant` 可以导入本门面**（闸门在 tool/check_layers.dart）。
library;

export 'src/rust/api/assistant.dart';
export 'src/rust/api/js.dart';
