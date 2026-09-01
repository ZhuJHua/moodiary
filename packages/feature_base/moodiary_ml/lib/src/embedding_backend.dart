import 'dart:typed_data';

/// 可替换的嵌入推理后端；业务只见这个接口。
abstract class EmbeddingBackend {
  bool get loaded;

  /// ONNX 模型是裸计算图，分词器（HF tokenizer.json）与 pad token 随模型给。
  Future<void> load(
    String modelPath, {
    required String tokenizerPath,
    required String padToken,
    int contextSize = 512,
  });

  Future<void> unload();

  /// 按输入顺序返回 L2 归一化后的向量。
  Future<List<Float32List>> embed(List<String> texts);
}
