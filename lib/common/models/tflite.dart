class SquadExample {
  /// A single training/test example for simple sequence classification.
  /// For examples without an answer, the start and end position are -1.

  final String qasId;
  final String questionText;
  final List<String> docTokens;
  final String? origAnswerText;
  final int? startPosition;
  final int? endPosition;
  final bool isImpossible;

  SquadExample({
    required this.qasId,
    required this.questionText,
    required this.docTokens,
    this.origAnswerText,
    this.startPosition,
    this.endPosition,
    this.isImpossible = false,
  });

  @override
  String toString() => _repr();

  String _repr() {
    final s = StringBuffer();
    s.write('qas_id: ${_printableText(qasId)}, ');
    s.write('question_text: ${_printableText(questionText)}, ');
    s.write('doc_tokens: [${docTokens.join(' ')}]');
    if (startPosition != null) {
      s.write(', start_position: $startPosition');
    }
    if (endPosition != null) {
      s.write(', end_position: $endPosition');
    }
    if (startPosition != null) {
      s.write(', is_impossible: $isImpossible');
    }
    return s.toString();
  }

  String _printableText(String text) {
    // 假设你有相应的函数来处理可打印文本
    return text.replaceAll('\n', ' ').trim();
  }
}

class InputFeatures {
  /// A single set of features of data.

  final int uniqueId;
  final String qasId;
  final int exampleIndex;
  final int docSpanIndex;
  final List<String> tokens;
  final Map<int, int> tokenToOrigMap;
  final Map<int, bool> tokenIsMaxContext;
  final List<int> inputIds;
  final List<int> inputMask;
  final List<int> segmentIds;
  final int? startPosition;
  final int? endPosition;
  final bool? isImpossible;

  InputFeatures({
    required this.uniqueId,
    required this.qasId,
    required this.exampleIndex,
    required this.docSpanIndex,
    required this.tokens,
    required this.tokenToOrigMap,
    required this.tokenIsMaxContext,
    required this.inputIds,
    required this.inputMask,
    required this.segmentIds,
    this.startPosition,
    this.endPosition,
    this.isImpossible,
  });

  @override
  String toString() {
    return 'InputFeatures{uniqueId: $uniqueId, qasId: $qasId, exampleIndex: $exampleIndex, docSpanIndex: $docSpanIndex, tokens: $tokens, tokenToOrigMap: $tokenToOrigMap, tokenIsMaxContext: $tokenIsMaxContext, inputIds: $inputIds, inputMask: $inputMask, segmentIds: $segmentIds, startPosition: $startPosition, endPosition: $endPosition, isImpossible: $isImpossible}';
  }
}

class DocSpan {
  final int start;
  final int length;

  DocSpan({required this.start, required this.length});
}

class RawResult {
  final int uniqueId;
  final List<double> startLogits;
  final List<double> endLogits;

  RawResult({
    required this.uniqueId,
    required this.startLogits,
    required this.endLogits,
  });

  List<int> getAnswerIndices() {
    final int startIndex =
        startLogits.indexOf(startLogits.reduce((a, b) => a > b ? a : b));
    final int endIndex =
        endLogits.indexOf(endLogits.reduce((a, b) => a > b ? a : b));
    return [startIndex, endIndex];
  }

  @override
  String toString() {
    return 'RawResult(uniqueId: $uniqueId, startLogits: $startLogits, endLogits: $endLogits)';
  }
}
