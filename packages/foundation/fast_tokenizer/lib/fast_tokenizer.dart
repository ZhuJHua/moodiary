/// 快速分词器：jieba（搜索索引 / 关键词）与 HF tokenizer.json（ONNX 推理），原生侧是自带的
/// `libfasttokenizer`，经 flutter_rust_bridge 调用。
///
/// 用法：启动时 `await FastTokenizer.ensureInitialized()`；宿主测试用 `testing.dart` 的替身。
library;

export 'src/runtime.dart';
export 'src/rust/api/hf_tokenizer.dart';
export 'src/rust/api/text.dart';
export 'src/rust/frb_generated.dart' show FastTokenizerLib;
