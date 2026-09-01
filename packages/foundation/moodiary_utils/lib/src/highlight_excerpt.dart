/// 取首个命中关键词前后各 [contextLength] 字的摘要，溢出补省略号；无命中退回前 200 字。
String getHighlightedExcerpt(
  String content,
  List<String> keywords, {
  int contextLength = 50,
}) {
  for (final word in keywords) {
    final index = content.indexOf(word);
    if (index != -1) {
      final wordStart = index;
      final wordEnd = index + word.length;

      int start = wordStart - contextLength;
      int end = wordEnd + contextLength;

      if (start < 0) {
        end += -start;
        start = 0;
      }
      if (end > content.length) {
        final overflow = end - content.length;
        start = (start - overflow).clamp(0, content.length);
        end = content.length;
      }

      final snippet = content.substring(start, end);
      final hasHead = start > 0;
      final hasTail = end < content.length;
      return "${hasHead ? '...' : ''}$snippet${hasTail ? '...' : ''}";
    }
  }

  final fallback = content.length > 200 ? content.substring(0, 200) : content;
  return "${fallback.trimRight()}${content.length > 200 ? '...' : ''}";
}
