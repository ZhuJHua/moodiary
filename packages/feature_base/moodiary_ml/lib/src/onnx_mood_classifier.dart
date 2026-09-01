import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:moodiary_rust/foundation.dart' show HfTokenizer;
import 'package:onnxruntime_plus/onnxruntime_plus.dart';

import 'onnx_embedding_backend.dart' show emptyPastInputs, ensureOrtEnv;

/// 单选题的候选项。key 由消费侧定义并映射回领域枚举；description 是给模型看的
/// 英文释义（写死不进 i18n）。2026-08-31 拍板英文作为基础提示词（状态要国际化、
/// 日记本身可能是任意语言）；同套 22 条中文样例实测英文两段式 12/22 vs 中文
/// 15/22，这 3 条差距是知情接受的代价。
typedef MoodOption = ({String key, String description});

/// 小型 LLM（Qwen3 decoder ONNX）受限单 token 分类器，不是生成——把候选项列成
/// A/B/C… 选择题，prompt 前向一次后只在候选字母 token 的 logits 上 argmax：
/// 结构上不可能答出清单外的东西，没有采样、没有输出解析、没有幻觉面。
/// 思考模式实测废案：think 普遍 250–450+ token，手机上是分钟级时延。
///
/// 前向拆两段，绕开合并版 decoder 图「logits 覆盖全部位置」的内存墙
/// （[1, seq, 151936] fp32 在 500 token 时 ~300MB）：
///   1. 喂 prompt[0..n-1)，只要 present KV——ORT 按需剪图，lm_head 不算，
///      巨型 logits 缓冲不存在；
///   2. 喂末位 token + 第一段的 KV，只要 logits，形状 [1, 1, V]（~600KB）。
/// present 张量始终以原生句柄（address）回喂，不物化成 Dart 列表。
final class OnnxMoodClassifier {
  OrtSession? _session;
  HfTokenizer? _tokenizer;

  List<String> _pastNames = const [];
  List<String> _presentNames = const [];
  bool _hasPositionIds = false;

  /// 参与分类的正文上限（字符）。再长对判断增益有限，纯付 prefill 时延。
  static const _maxChars = 800;

  bool get loaded => _session != null;

  Future<void> load(
    String modelPath, {
    required String tokenizerPath,
    int contextSize = 4096,
  }) async {
    if (_session != null) return;
    ensureOrtEnv();
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

  /// 问一道单选题，返回最贴合的候选项 key 与该项在候选集内的 softmax 置信度。
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

  /// Qwen3 chat template，思考关闭（空 <think> 块是官方非思考模式的生成前缀，
  /// 少了它首个输出 token 是 <|think|>）。
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

  /// 两段式前向，返回 prompt 末位处下一 token 的全词表 logits。
  Future<Float32List> _nextTokenLogits(
    OrtSession session,
    Uint32List tokens,
  ) async {
    final n = tokens.length;
    assert(n >= 2, 'prompt must have at least 2 tokens');

    Int64List ones(int count) => Int64List(count)..fillRange(0, count, 1);

    // ---- 第一段：prompt[0..n-1)，只要 present KV ----
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

    // ---- 第二段：末位 token + KV，只要 logits ----
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
      // [1][1][V]
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
