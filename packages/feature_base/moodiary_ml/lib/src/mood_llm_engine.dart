import 'dart:async';

import 'package:injectable/injectable.dart';

import 'mood_llm_models.dart';
import 'onnx_mood_classifier.dart';

/// 心情建议引擎：懒加载激活模型、空闲自动卸载，形态同 EmbeddingEngine。
/// int8 模型常驻 ~600MB RAM，空闲窗口比嵌入引擎收得更紧。
/// 提问结构（两段式选择题）与标签表在消费侧（moodiary_diary），本包只管机制。
@LazySingleton()
class MoodLlmEngine {
  final MoodLlmModelManager _models;

  /// 串行化加载/卸载/推理——保证同一时刻至多一个模型驻留内存。
  Future<void> _chain = Future.value();
  Timer? _idleTimer;
  final OnnxMoodClassifier _classifier = OnnxMoodClassifier();
  String? _loadedModelId;

  static const _idleUnload = Duration(seconds: 30);

  MoodLlmEngine(this._models);

  /// 心情建议是否可用（有激活模型即可用；真正加载推迟到首次提问）。
  bool get ready => _models.active != null;

  /// 问一道单选题；未启用时抛 [StateError]。
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
      _chain = _chain.then((_) => _classifier.unload());
    });
  }

  /// 立即释放模型（停用模型 / 重置数据时调用）。
  Future<void> dispose() {
    _idleTimer?.cancel();
    _chain = _chain.then((_) => _classifier.unload());
    return _chain;
  }
}
