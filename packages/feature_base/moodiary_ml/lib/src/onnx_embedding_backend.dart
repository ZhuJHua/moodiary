import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:moodiary_rust/foundation.dart' show HfTokenizer;
import 'package:onnxruntime_plus/onnxruntime_plus.dart';

import 'embedding_backend.dart';

var _ortEnvReady = false;

/// OrtEnv 是进程级单例且 init 无幂等保护，全仓只经这里初始化。
void ensureOrtEnv() {
  if (_ortEnvReady) return;
  OrtEnv.instance.init();
  _ortEnvReady = true;
}

/// ONNX Runtime（onnxruntime_plus，FFI 直调）嵌入后端，Qwen3-Embedding 系。
/// last-token 池化 + L2 归一化；分词走 Rust 的 HF tokenizers（读模型自带
/// tokenizer.json，其 post-processor 自动补尾部 `<|endoftext|>`，池化取的
/// 就是这个 EOS 位）。右 padding + causal attention 下，末位真实 token 的
/// hidden state 不受 pad 影响，取 len-1 即正确。
///
/// **恒 CPU**（bge 时代真机 benchmark，PJZ110）：int8 单条 19.0ms / 49.2 chunks/s；
/// XNNPACK EP 与默认 CPU 持平（int8 QLinear 算子不在其覆盖面），不启用。
/// 前向经 runAsync 在独立 isolate 执行，不阻塞调用方。
final class OnnxEmbeddingBackend implements EmbeddingBackend {
  OrtSession? _session;
  HfTokenizer? _tokenizer;
  int _padId = 0;

  @override
  bool get loaded => _session != null;

  @override
  Future<void> load(
    String modelPath, {
    required String tokenizerPath,
    required String padToken,
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
  }

  @override
  Future<void> unload() async {
    _session?.release();
    _session = null;
    _tokenizer = null;
  }

  @override
  Future<List<Float32List>> embed(List<String> texts) async {
    final session = _session;
    final tokenizer = _tokenizer;
    if (session == null || tokenizer == null) {
      throw StateError('embedding backend not loaded');
    }
    if (texts.isEmpty) return const [];

    final encoded = await tokenizer.encodeBatch(texts: texts);
    final rows = await runEncoder(session, encoded, padId: _padId);
    return [
      for (final (i, row) in rows.indexed)
        // [L][H] 取末位真实 token；[H] 视作已在图里池化。
        normalized(
          row.first is List ? (row[encoded[i].length - 1] as List) : row,
        ),
    ];
  }
}

/// Qwen3 系 decoder 形态导出图的空 past KV 输入（[batch, 8 头, 0, 128 维]）。
/// 图上每个 `past_key_values.*` 输入都是必填的，即便不带缓存也要喂零长度张量。
Map<String, OrtValueTensor> emptyPastInputs(OrtSession session, int batch) => {
  for (final name in session.inputNames)
    if (name.startsWith('past_key_values.'))
      name: OrtValueTensor.createTensorWithDataList(Float32List(0), [
        batch,
        8,
        0,
        128,
      ]),
};

/// 组批（右 padding + attention mask + position_ids + 空 KV）跑一次前向，
/// 只取 `last_hidden_state`（不取的话 56 个 present KV 白算白物化），按 batch
/// 拆开返回嵌套 List（每项 [L][H]）。
Future<List<List>> runEncoder(
  OrtSession session,
  List<Uint32List> encoded, {
  required int padId,
}) async {
  final batch = encoded.length;
  final maxLen = encoded.map((e) => e.length).reduce(math.max);

  final inputIds = Int64List(batch * maxLen);
  final attentionMask = Int64List(batch * maxLen);
  final positionIds = Int64List(batch * maxLen);
  for (var i = 0; i < batch; i++) {
    final tokens = encoded[i];
    for (var j = 0; j < maxLen; j++) {
      final offset = i * maxLen + j;
      inputIds[offset] = j < tokens.length ? tokens[j] : padId;
      attentionMask[offset] = j < tokens.length ? 1 : 0;
      positionIds[offset] = j;
    }
  }

  final shape = [batch, maxLen];
  final runOptions = OrtRunOptions();
  final inputs = <String, OrtValueTensor>{
    'input_ids': OrtValueTensor.createTensorWithDataList(inputIds, shape),
    'attention_mask': OrtValueTensor.createTensorWithDataList(
      attentionMask,
      shape,
    ),
    if (session.inputNames.contains('position_ids'))
      'position_ids': OrtValueTensor.createTensorWithDataList(
        positionIds,
        shape,
      ),
    ...emptyPastInputs(session, batch),
  };
  List<OrtValue?>? outputs;
  try {
    outputs = await session.runAsync(runOptions, inputs, [
      session.outputNames.first,
    ]);
    final value = outputs?.first?.value;
    if (value is! List || value.length != batch) {
      throw StateError('unexpected encoder output: ${value.runtimeType}');
    }
    return [for (final row in value) row as List];
  } finally {
    for (final value in outputs ?? const <OrtValue?>[]) {
      value?.release();
    }
    for (final value in inputs.values) {
      value.release();
    }
    runOptions.release();
  }
}

/// L2 归一化成 Float32List。
Float32List normalized(List vector) {
  final result = Float32List(vector.length);
  var normSquared = 0.0;
  for (var i = 0; i < vector.length; i++) {
    final v = (vector[i] as num).toDouble();
    result[i] = v;
    normSquared += v * v;
  }
  if (normSquared > 0) {
    final scale = 1.0 / math.sqrt(normSquared);
    for (var i = 0; i < result.length; i++) {
      result[i] *= scale;
    }
  }
  return result;
}
