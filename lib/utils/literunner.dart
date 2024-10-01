import 'dart:typed_data';

import 'package:mood_diary/common/models/tflite.dart';
import 'package:mood_diary/utils/tokenization.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Runs inference with a TensorFlow Lite model.
class LiteRunner {
  late Interpreter _interpreter;
  late IsolateInterpreter _isolateInterpreter;

  late FullTokenizer _tokenizer;

  Future<void> initializeInterpreter(String modelPath, tokenizer) async {
    // 加载模型
    _interpreter = await Interpreter.fromAsset(modelPath);
    // 分配张量
    _interpreter.allocateTensors();
    _isolateInterpreter = await IsolateInterpreter.create(address: _interpreter.address);
    _tokenizer = tokenizer;
  }

  /// 运行模型推理
  Future<RawResult> _run({
    required List<int> inputIds,
    required List<int> inputMask,
    required List<int> segmentIds,
    required int uniqueId,
  }) async {
    // 准备输入列表
    var inputs = [
      Int32List.fromList(inputIds).reshape([1, 384]),
      Int32List.fromList(inputMask).reshape([1, 384]),
      Int32List.fromList(segmentIds).reshape([1, 384]),
    ];

    // 准备输出缓冲区
    var endLogitsBuffer = List<double>.filled(384, 0).reshape([1, 384]);
    var startLogitsBuffer = List<double>.filled(384, 0).reshape([1, 384]);
    var output = {0: endLogitsBuffer, 1: startLogitsBuffer};
    // 运行推理
    await _isolateInterpreter.runForMultipleInputs(inputs, output);

    // 将输出转换为List<double>
    List<double> endLogits = List<double>.from(endLogitsBuffer[0]);
    List<double> startLogits = List<double>.from(startLogitsBuffer[0]);

    // 返回结果
    return RawResult(
      uniqueId: uniqueId,
      startLogits: startLogits,
      endLogits: endLogits,
    );
  }

  Future<String?> ask(String doc, String question) async {
    // 创建数据
    List<SquadExample> examples = [
      SquadExample(
        qasId: "1",
        questionText: question,
        docTokens: _tokenizer.tokenize(doc),
        startPosition: 0,
        endPosition: 1,
        isImpossible: false,
      ),
    ];
    // 转换为特征
    List<InputFeatures> features = await convertExamplesToFeatures(
      examples: examples,
      tokenizer: _tokenizer,
      maxSeqLength: 384,
      docStride: 128,
      maxQueryLength: 64,
    );

    var res = await _run(
        inputIds: features.first.inputIds,
        inputMask: features.first.inputMask,
        segmentIds: features.first.segmentIds,
        uniqueId: DateTime.now().millisecondsSinceEpoch);

    var answerIndices = res.getAnswerIndices();

    if (answerIndices.first < answerIndices.last) {
      return features.first.tokens.sublist(res.getAnswerIndices()[0], res.getAnswerIndices()[1] + 1).join('');
    } else {
      return null;
    }
  }

  // 定义转换函数
  Future<List<InputFeatures>> convertExamplesToFeatures({
    required List<SquadExample> examples,
    required FullTokenizer tokenizer,
    required int maxSeqLength,
    required int docStride,
    required int maxQueryLength,
  }) async {
    int uniqueId = 1000000000;
    List<InputFeatures> features = [];

    for (int exampleIndex = 0; exampleIndex < examples.length; exampleIndex++) {
      SquadExample example = examples[exampleIndex];
      List<String> queryTokens = tokenizer.basicTokenizer.tokenize(example.questionText);
      if (queryTokens.length > maxQueryLength) {
        queryTokens = queryTokens.sublist(0, maxQueryLength);
      }

      List<int> tokToOrigIndex = [];
      List<int> origToTokIndex = [];
      List<String> allDocTokens = [];

      for (int i = 0; i < example.docTokens.length; i++) {
        origToTokIndex.add(allDocTokens.length);
        List<String> subTokens = tokenizer.wordPieceTokenizer.tokenize(example.docTokens[i]);
        for (var subToken in subTokens) {
          tokToOrigIndex.add(i);
          allDocTokens.add(subToken);
        }
      }

      int maxTokensForDoc = maxSeqLength - queryTokens.length - 3;

      // 滑动窗口
      List<DocSpan> docSpans = [];
      int startOffset = 0;
      while (startOffset < allDocTokens.length) {
        int length = allDocTokens.length - startOffset;
        if (length > maxTokensForDoc) {
          length = maxTokensForDoc;
        }
        docSpans.add(DocSpan(start: startOffset, length: length));
        if (startOffset + length == allDocTokens.length) {
          break;
        }
        startOffset += (length < docStride) ? length : docStride;
      }

      for (int docSpanIndex = 0; docSpanIndex < docSpans.length; docSpanIndex++) {
        DocSpan docSpan = docSpans[docSpanIndex];
        List<String> tokens = [];
        Map<int, int> tokenToOrigMap = {};
        Map<int, bool> tokenIsMaxContext = {};
        List<int> segmentIds = [];

        tokens.add("[CLS]");
        segmentIds.add(0);
        for (var token in queryTokens) {
          tokens.add(token);
          segmentIds.add(0);
        }
        tokens.add("[SEP]");
        segmentIds.add(0);

        for (int i = 0; i < docSpan.length; i++) {
          int splitTokenIndex = docSpan.start + i;
          tokenToOrigMap[tokens.length] = tokToOrigIndex[splitTokenIndex];

          bool isMaxContext = _checkIsMaxContext(docSpans, docSpanIndex, splitTokenIndex);
          tokenIsMaxContext[tokens.length] = isMaxContext;

          tokens.add(allDocTokens[splitTokenIndex]);
          segmentIds.add(1);
        }
        tokens.add("[SEP]");
        segmentIds.add(1);

        List<int> inputIds = tokens
            .map((token) => tokenizer.wordPieceTokenizer.vocab[token] ?? tokenizer.wordPieceTokenizer.vocab["[UNK]"]!)
            .toList();

        // 创建 input_mask
        List<int> inputMask = List.filled(inputIds.length, 1, growable: true);

        // 填充
        while (inputIds.length < maxSeqLength) {
          inputIds.add(0);
          inputMask.add(0);
          segmentIds.add(0);
        }

        // 截断
        if (inputIds.length > maxSeqLength) {
          inputIds = inputIds.sublist(0, maxSeqLength);
          inputMask = inputMask.sublist(0, maxSeqLength);
          segmentIds = segmentIds.sublist(0, maxSeqLength);
        }

        assert(inputIds.length == maxSeqLength);
        assert(inputMask.length == maxSeqLength);
        assert(segmentIds.length == maxSeqLength);

        int? startPosition;
        int? endPosition;

        InputFeatures feature = InputFeatures(
          uniqueId: uniqueId,
          qasId: example.qasId,
          exampleIndex: exampleIndex,
          docSpanIndex: docSpanIndex,
          tokens: tokens,
          tokenToOrigMap: tokenToOrigMap,
          tokenIsMaxContext: tokenIsMaxContext,
          inputIds: inputIds,
          inputMask: inputMask,
          segmentIds: segmentIds,
          startPosition: startPosition,
          endPosition: endPosition,
          isImpossible: example.isImpossible,
        );
        features.add(feature);
        uniqueId += 1;
      }
    }

    return features;
  }

  bool _checkIsMaxContext(List<DocSpan> docSpans, int docSpanIndex, int splitTokenIndex) {
    double? bestScore;
    int? bestSpanIndex;

    for (int spanIndex = 0; spanIndex < docSpans.length; spanIndex++) {
      DocSpan docSpan = docSpans[spanIndex];
      int end = docSpan.start + docSpan.length - 1;

      if (splitTokenIndex < docSpan.start || splitTokenIndex > end) {
        continue;
      }

      int numLeftContext = splitTokenIndex - docSpan.start;
      int numRightContext = end - splitTokenIndex;
      double score = (numLeftContext < numRightContext ? numLeftContext.toDouble() : numRightContext.toDouble()) +
          0.01 * docSpan.length;

      if (bestScore == null || score > bestScore) {
        bestScore = score;
        bestSpanIndex = spanIndex;
      }
    }

    return docSpanIndex == bestSpanIndex;
  }

  void close() {
    _interpreter.close();
    _isolateInterpreter.close();
  }
}
