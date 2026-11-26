import 'dart:async';
import 'dart:typed_data';

import 'package:moodiary_storage/moodiary_storage.dart';

import 'embedding_backend.dart';
import 'embedding_models.dart';

abstract class SemanticEmbedder {
  bool get ready;

  int get dim;

  Future<List<Float32List>> embedPassages(List<String> texts);

  Future<Float32List> embedQuery(String text);

  Future<void> dispose();
}

class EmbeddingEngine implements SemanticEmbedder {
  final EmbeddingModelManager _models;
  final EmbeddingBackend _backend;

  Future<void> _chain = Future.value();
  Timer? _idleTimer;
  bool _disposed = false;

  String? _loadedModelId;

  static const _idleUnload = Duration(seconds: 60);

  EmbeddingEngine(this._models, this._backend);

  @override
  bool get ready => _models.active != null;

  @override
  int get dim => MoodiaryKVs.embeddingDim.get() ?? 0;

  @override
  Future<List<Float32List>> embedPassages(List<String> texts) {
    final spec = _requireActive();
    return _run([for (final t in texts) '${spec.passagePrefix}$t'], spec);
  }

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
    if (_disposed) throw StateError('EmbeddingEngine is disposed');
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
    _chain = task.then(
      (_) => _armIdleUnload(),
      onError: (_) => _armIdleUnload(),
    );
    return task;
  }

  void _armIdleUnload() {
    if (_disposed) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleUnload, () {
      _chain = _chain.then((_) => _backend.unload());
    });
  }

  @override
  Future<void> dispose() {
    if (_disposed) return _chain;
    _disposed = true;
    _idleTimer?.cancel();
    _chain = _chain.then((_) => _backend.unload());
    return _chain;
  }
}
