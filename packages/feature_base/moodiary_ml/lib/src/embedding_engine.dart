import 'dart:async';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'embedding_backend.dart';
import 'embedding_models.dart';
import 'onnx_embedding_backend.dart';

/// 语义嵌入的消费侧窄接口（moodiary_data 的 EmbedIndexService 面向它，
/// 测试注入确定性替身）。生产实现是 [EmbeddingEngine]。
abstract class SemanticEmbedder {
  bool get ready;

  int get dim;

  Future<List<Float32List>> embedPassages(List<String> texts);

  Future<Float32List> embedQuery(String text);
}

/// 嵌入引擎：懒加载激活模型、空闲自动卸载（Q8 模型常驻约 40MB RAM，不长期占用）。
/// 调用方不感知前缀与加载时机。
@LazySingleton()
class EmbeddingEngine implements SemanticEmbedder {
  final EmbeddingModelManager _models;
  final EmbeddingBackend _backend;

  /// 串行化加载/卸载/推理——保证同一时刻至多一个模型驻留内存。
  Future<void> _chain = Future.value();
  Timer? _idleTimer;

  /// backend 当前驻留的模型；切换激活模型后必须先卸载再载新的。
  String? _loadedModelId;

  static const _idleUnload = Duration(seconds: 60);

  EmbeddingEngine(this._models, this._backend);

  /// 语义检索是否可用（有激活模型即可用；真正加载推迟到首次嵌入）。
  @override
  bool get ready => _models.active != null;

  @override
  int get dim => MoodiaryKVs.embeddingDim.get() ?? 0;

  /// 索引侧：整批嵌入正文分块（带模型的 passage 前缀，bge 系为空）。
  @override
  Future<List<Float32List>> embedPassages(List<String> texts) {
    final spec = _requireActive();
    return _run([for (final t in texts) '${spec.passagePrefix}$t'], spec);
  }

  /// 查询侧：带模型自己的指令前缀（bge-zh 与 EmbeddingGemma 契约不同，见清单）。
  @override
  Future<Float32List> embedQuery(String text) async {
    final spec = _requireActive();
    return (await _run(['${spec.queryPrefix}$text'], spec)).single;
  }

  EmbeddingModelSpec _requireActive() {
    final spec = _models.active;
    if (spec == null) {
      throw StateError('no embedding model activated');
    }
    return spec;
  }

  Future<List<Float32List>> _run(List<String> texts, EmbeddingModelSpec spec) {
    if (texts.isEmpty) return Future.value(const []);
    final task = _chain.then((_) async {
      _idleTimer?.cancel();
      if (_backend.loaded && _loadedModelId != spec.id) {
        await _backend.unload();
        _loadedModelId = null;
      }
      if (!_backend.loaded) {
        await _backend.load(
          _models.modelPathOf(spec),
          tokenizerPath: _models.tokenizerPathOf(spec),
          padToken: spec.padToken,
          contextSize: spec.contextSize,
        );
        _loadedModelId = spec.id;
      }
      return _backend.embed(texts);
    });
    // 失败不打断链（下一次调用照常排队），但要重新武装空闲卸载。
    _chain = task.then(
      (_) => _armIdleUnload(),
      onError: (_) => _armIdleUnload(),
    );
    return task;
  }

  void _armIdleUnload() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleUnload, () {
      _chain = _chain.then((_) => _backend.unload());
    });
  }

  /// 立即释放模型（停用模型 / 重置数据时调用）。
  Future<void> dispose() {
    _idleTimer?.cancel();
    _chain = _chain.then((_) => _backend.unload());
    return _chain;
  }
}

/// DI 装配：后端 = ONNX Runtime（全仓唯一推理运行时）。
@module
abstract class EmbeddingBackendModule {
  @lazySingleton
  EmbeddingBackend backend() => OnnxEmbeddingBackend();
}
