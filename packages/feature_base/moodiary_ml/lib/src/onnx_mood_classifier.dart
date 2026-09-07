import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fast_tokenizer/fast_tokenizer.dart'
    show FastTokenizer, HfTokenizer;
import 'package:onnxruntime_plus/onnxruntime_plus.dart';

import 'onnx_embedding_backend.dart' show emptyPastInputs, ensureOrtEnv;

typedef MoodOption = ({String key, String description});

final class OnnxMoodClassifier {
  OrtSession? _session;
  HfTokenizer? _tokenizer;

  List<String> _pastNames = const [];
  List<String> _presentNames = const [];
  bool _hasPositionIds = false;

  static const _maxChars = 800;

  bool get loaded => _session != null;

  Future<void> load(
    String modelPath, {
    required String tokenizerPath,
    int contextSize = 4096,
  }) async {
    if (_session != null) return;
    ensureOrtEnv();
    await FastTokenizer.ensureInitialized();
    final tokenizer = await HfTokenizer.fromFile(
      path: tokenizerPath,
      maxTokens: contextSize,
    );
    final session = OrtSession.fromFile(File(modelPath), OrtSessionOptions());
    const pastPrefix = 'past_key_values.';
    _pastNames = [
      for (final name in session.inputNames)
        if (name.startsWith(pastPrefix)) name,
    ];
    _presentNames = [
      for (final name in _pastNames)
        'present.${name.substring(pastPrefix.length)}',
    ];
    _hasPositionIds = session.inputNames.contains('position_ids');
    _session = session;
    _tokenizer = tokenizer;
  }

  Future<void> unload() async {
    _session?.release();
    _session = null;
    _tokenizer = null;
  }

  Future<(String, double)> ask(
    String text, {
    required String question,
    required List<MoodOption> options,
  }) async {
    final session = _session;
    final tokenizer = _tokenizer;
    if (session == null || tokenizer == null) {
      throw StateError('mood classifier not loaded');
    }
    if (options.isEmpty || options.length > 26) {
      throw ArgumentError('options must be 1..26, got ${options.length}');
    }

    final candidateIds = <int>[];
    for (var i = 0; i < options.length; i++) {
      final letter = String.fromCharCode(65 + i);
      final id = await tokenizer.tokenId(token: letter);
      if (id == null) throw StateError('letter token $letter not in vocab');
      candidateIds.add(id);
    }

    final prompt = _buildPrompt(text, question, options);
    final ids = await tokenizer.encode(text: prompt);
    final logits = await _nextTokenLogits(session, ids);

    var best = 0;
    for (var i = 1; i < candidateIds.length; i++) {
      if (logits[candidateIds[i]] > logits[candidateIds[best]]) best = i;
    }
    var expSum = 0.0;
    for (final id in candidateIds) {
      expSum += math.exp(logits[id] - logits[candidateIds[best]]);
    }
    return (options[best].key, 1.0 / expSum);
  }

  // 空 <think></think> 是关闭思考模式的生成前缀；少了它首个输出 token 会是 <|think|>。
  String _buildPrompt(String text, String question, List<MoodOption> options) {
    final content = text.length > _maxChars
        ? text.substring(0, _maxChars)
        : text;
    final buffer = StringBuffer()
      ..writeln('<|im_start|>user')
      ..writeln(question)
      ..writeln()
      ..writeln('Diary entry:')
      ..writeln('「$content」')
      ..writeln()
      ..writeln('Options:');
    for (var i = 0; i < options.length; i++) {
      final letter = String.fromCharCode(65 + i);
      buffer.writeln('$letter. ${options[i].description}');
    }
    buffer
      ..writeln()
      ..writeln('Reply with the option letter only.<|im_end|>')
      ..writeln('<|im_start|>assistant')
      ..writeln('<think>')
      ..writeln()
      ..writeln('</think>')
      ..writeln();
    return buffer.toString();
  }

  Future<Float32List> _nextTokenLogits(
    OrtSession session,
    Uint32List tokens,
  ) async {
    final n = tokens.length;
    assert(n >= 2, 'prompt must have at least 2 tokens');

    Int64List ones(int count) => Int64List(count)..fillRange(0, count, 1);

    final prefix = Int64List(n - 1);
    final positions = Int64List(n - 1);
    for (var i = 0; i < n - 1; i++) {
      prefix[i] = tokens[i];
      positions[i] = i;
    }
    final pass1 = <String, OrtValueTensor>{
      'input_ids': OrtValueTensor.createTensorWithDataList(prefix, [1, n - 1]),
      'attention_mask': OrtValueTensor.createTensorWithDataList(ones(n - 1), [
        1,
        n - 1,
      ]),
      if (_hasPositionIds)
        'position_ids': OrtValueTensor.createTensorWithDataList(positions, [
          1,
          n - 1,
        ]),
      ...emptyPastInputs(session, 1),
    };
    final runOptions1 = OrtRunOptions();
    List<OrtValue?>? presents;
    try {
      presents = await session.runAsync(runOptions1, pass1, _presentNames);
    } finally {
      for (final value in pass1.values) {
        value.release();
      }
      runOptions1.release();
    }
    if (presents == null || presents.length != _pastNames.length) {
      throw StateError('unexpected present outputs: ${presents?.length}');
    }

    final pass2 = <String, OrtValue>{
      'input_ids': OrtValueTensor.createTensorWithDataList(
        Int64List(1)..[0] = tokens[n - 1],
        [1, 1],
      ),
      'attention_mask': OrtValueTensor.createTensorWithDataList(ones(n), [
        1,
        n,
      ]),
      if (_hasPositionIds)
        'position_ids': OrtValueTensor.createTensorWithDataList(
          Int64List(1)..[0] = n - 1,
          [1, 1],
        ),
      for (final (i, name) in _pastNames.indexed) name: presents[i]!,
    };
    final runOptions2 = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = await session.runAsync(runOptions2, pass2, const ['logits']);
      final value = outputs?.first?.value;
      if (value is! List || value.length != 1) {
        throw StateError('unexpected logits output: ${value.runtimeType}');
      }
      final row = (value.first as List).first as List;
      final logits = Float32List(row.length);
      for (var i = 0; i < row.length; i++) {
        logits[i] = (row[i] as num).toDouble();
      }
      return logits;
    } finally {
      for (final value in outputs ?? const <OrtValue?>[]) {
        value?.release();
      }
      for (final value in pass2.values) {
        value.release();
      }
      runOptions2.release();
    }
  }
}
