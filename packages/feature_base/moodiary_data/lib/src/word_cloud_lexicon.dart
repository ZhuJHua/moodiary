// 词云词典：把 jieba 的分词结果按用户词典**重切**一遍。
//
// 为什么需要：上游 jieba 词典里 57% 的词条词频 ≤ 3，其中的多字长词会把相邻的
// 常用词粘成一个怪词（「存在性需求」被切成「存在 / 性需求」，因为词典里有
// 「性需求 3」而没有「存在性」）。运行时没有 API 能删词典条目，但我们可以在
// 计数侧用一份自己的词典把它们切回来。
//
// 规则（按用户词典最长匹配优先，未匹配处保留 jieba token 的剩余部分）：
//   词典含「存在性」：   存在 ｜ 性需求   →  存在性 ｜ 需求
//   词典含「今天」「天气」：今天天气        →  今天 ｜ 天气
// 只在全是汉字的连续片段里做，拉丁词/数字/标点原样穿过。

/// 词典词的最大长度（汉字数）：超过它的词不进 trie。
const int wordCloudLexiconMaxLength = 12;

class WordCloudLexicon {
  /// 全部词条（含单字）。单字不参与重切，只作为「保留名单」在过滤阶段生效。
  final Set<String> words;

  final _TrieNode _root;

  WordCloudLexicon(Iterable<String> words)
    : words = Set<String>.unmodifiable(words),
      _root = _TrieNode() {
    for (final word in this.words) {
      if (word.length < 2 || word.length > wordCloudLexiconMaxLength) continue;
      var node = _root;
      for (final unit in word.codeUnits) {
        node = node.children.putIfAbsent(unit, _TrieNode.new);
      }
      node.isWord = true;
    }
  }

  static final WordCloudLexicon empty = WordCloudLexicon(const []);

  bool get isEmpty => words.isEmpty;

  /// 词典里能参与重切的词数（≥ 2 字）。
  int get resegmentableCount => _root.countWords();

  /// 把 jieba 的 token 序列按词典重切。没有可改之处时原样返回。
  List<String> resegment(List<String> tokens) {
    if (words.isEmpty || tokens.isEmpty) return tokens;
    final out = <String>[];
    final run = StringBuffer();
    final starts = <int>[];
    final ends = <int>[];
    var length = 0;
    var changed = false;

    void flush() {
      if (length == 0) return;
      final text = run.toString();
      final resegmented = _resegmentRun(text, starts, ends);
      if (resegmented.length != ends.length) {
        changed = true;
      } else {
        for (var i = 0; i < resegmented.length; i++) {
          if (resegmented[i] != text.substring(starts[i], ends[i])) {
            changed = true;
            break;
          }
        }
      }
      out.addAll(resegmented);
      run.clear();
      starts.clear();
      ends.clear();
      length = 0;
    }

    for (final token in tokens) {
      if (_isHanOnly(token)) {
        starts.add(length);
        run.write(token);
        length += token.length;
        ends.add(length);
      } else {
        flush();
        out.add(token);
      }
    }
    flush();
    return changed ? out : tokens;
  }

  List<String> _resegmentRun(String text, List<int> starts, List<int> ends) {
    final out = <String>[];
    var index = 0;
    var token = 0;
    while (index < text.length) {
      final match = _longestMatch(text, index);
      if (match != null) {
        out.add(match);
        index += match.length;
        continue;
      }
      // 没匹配到词典：把这个 token 的剩余部分整个吐出去（跨 token 的匹配
      // 会切掉它的头，剩下的部分就是「需求」这种尾巴）。
      while (token < ends.length && ends[token] <= index) {
        token++;
      }
      if (token >= ends.length) {
        out.add(text.substring(index));
        break;
      }
      out.add(text.substring(index, ends[token]));
      index = ends[token];
      token++;
    }
    return out;
  }

  /// 从 [index] 起的最长词典匹配（≥ 2 字）；没有就返回 null。
  String? _longestMatch(String text, int index) {
    var node = _root;
    var best = -1;
    for (var i = index; i < text.length; i++) {
      final next = node.children[text.codeUnitAt(i)];
      if (next == null) break;
      node = next;
      if (node.isWord) best = i;
    }
    return best < 0 ? null : text.substring(index, best + 1);
  }

  static bool _isHanOnly(String token) {
    if (token.isEmpty) return false;
    for (final unit in token.codeUnits) {
      if (!_isHan(unit)) return false;
    }
    return true;
  }

  /// 汉字区间（基本区 + 扩展 A），够覆盖日记里的用字。
  static bool _isHan(int unit) =>
      (unit >= 0x4E00 && unit <= 0x9FFF) || (unit >= 0x3400 && unit <= 0x4DBF);
}

class _TrieNode {
  final Map<int, _TrieNode> children = {};
  bool isWord = false;

  int countWords() {
    var count = isWord ? 1 : 0;
    for (final child in children.values) {
      count += child.countWords();
    }
    return count;
  }
}
