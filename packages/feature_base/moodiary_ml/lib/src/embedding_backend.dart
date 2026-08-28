import 'dart:typed_data';

import 'package:llamadart/llamadart.dart';

/// 可替换的嵌入推理后端；llamadart 依赖收口在本文件，业务只见这个接口。
abstract class EmbeddingBackend {
  bool get loaded;

  Future<void> load(String modelPath, {int contextSize = 512});

  Future<void> unload();

  /// 按输入顺序返回 L2 归一化后的向量。
  Future<List<Float32List>> embed(List<String> texts);
}

/// llama.cpp（经 llamadart）后端。嵌入模型最大也只有 0.3B 参数量级，GPU 无收益，
/// 恒 CPU；上下文长度随模型（spec.contextSize）。
final class LlamaEmbeddingBackend implements EmbeddingBackend {
  LlamaEngine? _engine;

  @override
  bool get loaded => _engine != null;

  @override
  Future<void> load(String modelPath, {int contextSize = 512}) async {
    if (_engine != null) return;
    final engine = LlamaEngine(LlamaBackend());
    try {
      await engine.loadModel(
        modelPath,
        modelParams: ModelParams(
          contextSize: contextSize,
          gpuLayers: 0,
          preferredBackend: GpuBackend.cpu,
        ),
      );
    } catch (_) {
      await engine.dispose();
      rethrow;
    }
    _engine = engine;
  }

  @override
  Future<void> unload() async {
    final engine = _engine;
    _engine = null;
    await engine?.dispose();
  }

  @override
  Future<List<Float32List>> embed(List<String> texts) async {
    final engine = _engine;
    if (engine == null) {
      throw StateError('embedding backend not loaded');
    }
    final vectors = await engine.embedBatch(texts, normalize: true);
    return [for (final v in vectors) Float32List.fromList(v)];
  }
}
