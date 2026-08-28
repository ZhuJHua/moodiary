import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:injectable/injectable.dart';
import 'package:moodiary_rust/foundation.dart' show HfTokenizer;
import 'package:onnxruntime_plus/onnxruntime_plus.dart';

import 'onnx_embedding_backend.dart' show ensureOrtEnv, runEncoder;
import 'sentiment_models.dart';

/// 情感分类器：logits → softmax → 对逐标签效价权重加权 = 心情分 0..1。
/// 权重随模型 spec 给（标签序是各模型自己的契约，不能假设升序）。
final class OnnxSentimentClassifier {
  OrtSession? _session;
  HfTokenizer? _tokenizer;
  int _padId = 0;
  List<double> _labelWeights = const [0, 0.25, 0.5, 0.75, 1];

  bool get loaded => _session != null;

  Future<void> load(
    String modelPath, {
    required String tokenizerPath,
    required String padToken,
    required List<double> labelWeights,
    int contextSize = 512,
  }) async {
    if (_session != null) return;
    ensureOrtEnv();
    final tokenizer = await HfTokenizer.fromFile(
      path: tokenizerPath,
      maxTokens: contextSize,
    );
    final padId = await tokenizer.tokenId(token: padToken);
    if (padId == null) {
      throw StateError('pad token $padToken not in vocab');
    }
    _session = OrtSession.fromFile(File(modelPath), OrtSessionOptions());
    _tokenizer = tokenizer;
    _padId = padId;
    _labelWeights = labelWeights;
  }

  Future<void> unload() async {
    _session?.release();
    _session = null;
    _tokenizer = null;
  }

  /// 心情分 0..1（0=很差，1=很好）。
  Future<double> score(String text) async {
    final session = _session;
    final tokenizer = _tokenizer;
    if (session == null || tokenizer == null) {
      throw StateError('sentiment classifier not loaded');
    }
    final ids = await tokenizer.encode(text: text);
    final rows = await runEncoder(session, [ids], padId: _padId);
    final logitsRow = rows.single;
    if (logitsRow.length != _labelWeights.length || logitsRow.first is List) {
      throw StateError('unexpected logits shape [${logitsRow.length}]');
    }
    return _expectation([for (final v in logitsRow) (v as num).toDouble()]);
  }

  double _expectation(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exps = [for (final l in logits) math.exp(l - maxLogit)];
    final sum = exps.reduce((a, b) => a + b);
    var expectation = 0.0;
    for (var i = 0; i < exps.length; i++) {
      expectation += (exps[i] / sum) * _labelWeights[i];
    }
    return expectation;
  }
}

/// 情感引擎：懒加载激活模型、空闲自动卸载，形态同 EmbeddingEngine。
@LazySingleton()
class SentimentEngine {
  final SentimentModelManager _models;

  Future<void> _chain = Future.value();
  Timer? _idleTimer;
  final OnnxSentimentClassifier _classifier = OnnxSentimentClassifier();
  String? _loadedModelId;

  static const _idleUnload = Duration(seconds: 60);

  SentimentEngine(this._models);

  /// 心情建议是否可用（有激活模型即可用；真正加载推迟到首次打分）。
  bool get ready => _models.active != null;

  /// 建议心情 0..1；未启用返回 null。
  Future<double?> suggestMood(String text) {
    final spec = _models.active;
    if (spec == null || text.trim().isEmpty) return Future.value();
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
          padToken: spec.padToken,
          labelWeights: spec.labelWeights,
          contextSize: spec.contextSize,
        );
        _loadedModelId = spec.id;
      }
      return _classifier.score(text);
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

  /// 立即释放模型（停用模型 / 重置数据时调用）。
  Future<void> dispose() {
    _idleTimer?.cancel();
    _chain = _chain.then((_) => _classifier.unload());
    return _chain;
  }
}
