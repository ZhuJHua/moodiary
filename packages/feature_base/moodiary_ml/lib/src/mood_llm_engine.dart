import 'dart:async';

import 'package:injectable/injectable.dart';

import 'mood_llm_models.dart';
import 'onnx_mood_classifier.dart';

@LazySingleton()
class MoodLlmEngine {
  final MoodLlmModelManager _models;

  Future<void> _chain = Future.value();
  Timer? _idleTimer;
  final OnnxMoodClassifier _classifier = OnnxMoodClassifier();
  String? _loadedModelId;

  static const _idleUnload = Duration(seconds: 30);

  MoodLlmEngine(this._models);

  bool get ready => _models.active != null;

  Future<(String, double)> ask(
    String text, {
    required String question,
    required List<MoodOption> options,
  }) {
    final spec = _models.active;
    if (spec == null) {
      throw StateError('no mood llm activated');
    }
    final task = _chain.then((_) async {
      _idleTimer?.cancel();
      if (_classifier.loaded && _loadedModelId != spec.id) {
        await _classifier.unload();
        _loadedModelId = null;
      }
      if (!_classifier.loaded) {
        await _classifier.load(
          _models.modelPathOf(spec),
          tokenizerPath: _models.tokenizerPathOf(spec),
        );
        _loadedModelId = spec.id;
      }
      return _classifier.ask(text, question: question, options: options);
    });
    _chain = task.then(
      (_) => _armIdleUnload(),
      onError: (_) => _armIdleUnload(),
    );
    return task;
  }

  void _armIdleUnload() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleUnload, () {
      _chain = _chain.then((_) => _classifier.unload());
    });
  }

  @disposeMethod
  Future<void> dispose() {
    _idleTimer?.cancel();
    _chain = _chain.then((_) => _classifier.unload());
    return _chain;
  }
}
