import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fast_tokenizer/fast_tokenizer.dart'
    show FastTokenizer, HfTokenizer;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'embedding_backend.dart';

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
    await FastTokenizer.ensureInitialized();
    final tokenizer = await HfTokenizer.fromFile(
      path: tokenizerPath,
      maxTokens: contextSize,
    );
    final padId = await tokenizer.tokenId(token: padToken);
    if (padId == null) {
      throw StateError('pad token $padToken not in vocab');
    }
    _session = await OnnxRuntime().createSession(modelPath);
    _tokenizer = tokenizer;
    _padId = padId;
  }

  @override
  Future<void> unload() async {
    await _session?.close();
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
    return _runEncoder(session, encoded, padId: _padId);
  }
}

// past_key_values.* 全部必填，无缓存也要喂 [batch, 8 头, 0, 128 维] 的零长度张量。
Future<void> _addEmptyPastInputs(
  Map<String, OrtValue> inputs,
  OrtSession session,
  int batch,
) async {
  for (final name in session.inputNames) {
    if (!name.startsWith('past_key_values.')) continue;
    inputs[name] = await OrtValue.fromList(Float32List(0), [batch, 8, 0, 128]);
  }
}

Future<List<Float32List>> _runEncoder(
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
  final inputs = <String, OrtValue>{
    'input_ids': await OrtValue.fromList(inputIds, shape),
    'attention_mask': await OrtValue.fromList(attentionMask, shape),
  };
  if (session.inputNames.contains('position_ids')) {
    inputs['position_ids'] = await OrtValue.fromList(positionIds, shape);
  }
  await _addEmptyPastInputs(inputs, session, batch);

  Map<String, OrtValue>? outputs;
  try {
    outputs = await session.run(inputs);
    final name = session.outputNames.first;
    final value = outputs[name];
    if (value == null) {
      throw StateError('encoder output $name missing');
    }
    return _pool(await value.asFlattenedList(), value.shape, encoded);
  } finally {
    for (final value in outputs?.values ?? const <OrtValue>[]) {
      await value.dispose();
    }
    for (final value in inputs.values) {
      await value.dispose();
    }
  }
}

List<Float32List> _pool(
  List<dynamic> flat,
  List<int> shape,
  List<Uint32List> encoded,
) {
  final batch = encoded.length;
  if (shape.length == 2) {
    final dim = shape[1];
    return [for (var i = 0; i < batch; i++) _normalized(flat, i * dim, dim)];
  }
  if (shape.length == 3) {
    final seq = shape[1];
    final dim = shape[2];
    return [
      for (var i = 0; i < batch; i++)
        _normalized(flat, (i * seq + encoded[i].length - 1) * dim, dim),
    ];
  }
  throw StateError('unexpected encoder output shape: $shape');
}

Float32List _normalized(List<dynamic> flat, int offset, int length) {
  final result = Float32List(length);
  var normSquared = 0.0;
  for (var i = 0; i < length; i++) {
    final v = (flat[offset + i] as num).toDouble();
    result[i] = v;
    normSquared += v * v;
  }
  if (normSquared > 0) {
    final scale = 1.0 / math.sqrt(normSquared);
    for (var i = 0; i < length; i++) {
      result[i] *= scale;
    }
  }
  return result;
}
