import 'package:flutter/services.dart';

class FullTokenizer {
  late BasicTokenizer _basicTokenizer;
  late WordPieceTokenizer _wordPieceTokenizer;
  late Map<String, int> _vocab;
  late Map<int, String> _invVocab;

  BasicTokenizer get basicTokenizer => _basicTokenizer;

  Future<void> init() async {
    // 加载词表
    _vocab = await _loadVocab('assets/tflite/vocab.txt');
    _invVocab = {};
    // 创建反向词表
    _vocab.forEach((key, value) {
      _invVocab[value] = key;
    });
    _basicTokenizer = BasicTokenizer(doLowerCase: false);
    _wordPieceTokenizer = WordPieceTokenizer(_vocab);
  }

  List<String> tokenize(String text) {
    var splitTokens = <String>[];
    for (var token in _basicTokenizer.tokenize(text)) {
      for (var subToken in _wordPieceTokenizer.tokenize(token)) {
        splitTokens.add(subToken);
      }
    }
    return splitTokens;
  }

  List<int> convertTokensToIds(tokens) {
    var output = <int>[];
    for (var token in tokens) {
      output.add(_vocab[token]!);
    }
    return output;
  }

  List<String> convertIdsToTokens(ids) {
    var output = <String>[];
    for (var id in ids) {
      output.add(_invVocab[id]!);
    }
    return output;
  }

  Future<Map<String, int>> _loadVocab(String filePath) async {
    final vocab = <String, int>{};
    final lines = (await rootBundle.loadString(filePath)).split('\n');
    for (int i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (!vocab.containsKey(token)) {
        vocab[token] = i;
      }
    }
    return vocab;
  }

  WordPieceTokenizer get wordPieceTokenizer => _wordPieceTokenizer;

  Map<String, int> get vocab => _vocab;

  Map<int, String> get invVocab => _invVocab;
}

class BasicTokenizer {
  bool doLowerCase;

  BasicTokenizer({this.doLowerCase = true});

  // 将文本转为Unicode
  String convertToUnicode(String text) {
    return text; // Dart本身支持UTF-8编码，无需额外处理
  }

  // 分词主函数
  List<String> tokenize(String text) {
    text = convertToUnicode(text);
    text = _cleanText(text);
    text = _tokenizeChineseChars(text);

    // 基本的空白分割
    List<String> origTokens = _whitespaceTokenize(text);
    List<String> splitTokens = [];
    for (String token in origTokens) {
      if (doLowerCase) {
        token = token.toLowerCase();
        token = _runStripAccents(token);
      }
      splitTokens.addAll(_runSplitOnPunc(token));
    }

    return _whitespaceTokenize(splitTokens.join(" "));
  }

  // 清理文本，去除不合法字符
  String _cleanText(String text) {
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      if (_isWhitespace(char)) {
        buffer.write(" ");
      } else if (!_isControl(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  // 判断是否为中文字符，并在字符前后添加空格
  String _tokenizeChineseChars(String text) {
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      int cp = text.codeUnitAt(i);
      if (_isChineseChar(cp)) {
        buffer.write(" ");
        buffer.write(String.fromCharCode(cp));
        buffer.write(" ");
      } else {
        buffer.write(String.fromCharCode(cp));
      }
    }
    return buffer.toString();
  }

  bool _isChineseChar(int cp) {
    return (cp >= 0x4E00 && cp <= 0x9FFF);
  }

  // 分割标点符号
  List<String> _runSplitOnPunc(String token) {
    List<String> result = [];
    StringBuffer currentWord = StringBuffer();
    for (int i = 0; i < token.length; i++) {
      String char = token[i];
      if (_isPunctuation(char)) {
        if (currentWord.isNotEmpty) {
          result.add(currentWord.toString());
          currentWord.clear();
        }
        result.add(char);
      } else {
        currentWord.write(char);
      }
    }
    if (currentWord.isNotEmpty) result.add(currentWord.toString());
    return result;
  }

  bool _isPunctuation(String char) {
    int cp = char.codeUnitAt(0);
    return ((cp >= 33 && cp <= 47) || (cp >= 58 && cp <= 64)); // 判断ASCII标点符号
  }

  String _runStripAccents(String token) {
    // 去除重音符号
    return token; // Dart无需实现特殊处理
  }

  bool _isWhitespace(String char) {
    return char.trim().isEmpty;
  }

  bool _isControl(String char) {
    return false; // 控制字符不处理
  }

  List<String> _whitespaceTokenize(String text) {
    return text.trim().split(RegExp(r"\s+"));
  }
}

class WordPieceTokenizer {
  final Map<String, int> vocab;
  final String unkToken;
  final int maxInputCharsPerWord;

  WordPieceTokenizer(this.vocab, {this.unkToken = "[UNK]", this.maxInputCharsPerWord = 100});

  List<String> tokenize(String text) {
    List<String> outputTokens = [];
    List<String> tokens = text.split(" ");

    for (String token in tokens) {
      if (token.length > maxInputCharsPerWord) {
        outputTokens.add(unkToken);
        continue;
      }

      List<String> subTokens = [];
      bool isBad = false;
      int start = 0;

      while (start < token.length) {
        int end = token.length;
        String? curSubst;
        while (start < end) {
          String subst = token.substring(start, end);
          if (start > 0) subst = "##$subst";
          if (vocab.containsKey(subst)) {
            curSubst = subst;
            break;
          }
          end -= 1;
        }

        if (curSubst == null) {
          isBad = true;
          break;
        }
        subTokens.add(curSubst);
        start = end;
      }

      if (isBad) {
        outputTokens.add(unkToken);
      } else {
        outputTokens.addAll(subTokens);
      }
    }
    return outputTokens;
  }
}
