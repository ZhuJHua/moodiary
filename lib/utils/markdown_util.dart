class MarkdownConverter {
  static String convert(String markdown) {
    markdown = _normalizeLineEndings(markdown);
    markdown = _handleEscapedCharacters(markdown);
    markdown = _handleSpecialCases(markdown);

    markdown = _processNestedStructures(markdown);
    markdown = _processTables(markdown);
    markdown = _processLists(markdown);
    markdown = _removeHTMLAndComments(markdown);
    markdown = _processFormatting(markdown);
    markdown = _processBlocks(markdown);
    markdown = _processLinks(markdown);
    markdown = _processImages(markdown);
    markdown = _processMath(markdown);

    return _cleanupText(markdown);
  }

  static String _normalizeLineEndings(String input) {
    return input.replaceAll(RegExp(r'\r\n?|\n'), '\n');
  }

  static String _handleEscapedCharacters(String input) {
    return input.replaceAllMapped(RegExp(r'\\([\\*_`~{}\[\]()#+\-.!|])'),
        (match) {
      return match.group(1) ?? '';
    });
  }

  static String _handleSpecialCases(String input) {
    return input.replaceAllMapped(RegExp(r'&[a-zA-Z0-9#]+;'), (match) {
      return _htmlEntityMap[match.group(0)] ?? '';
    });
  }

  static String _processNestedStructures(String input) {
    // Placeholder for nested structures handling (e.g., blockquotes, nested lists).
    return input;
  }

  static String _processTables(String input) {
    return input.replaceAllMapped(RegExp(r'\|(.+?)\|'), (match) {
      return match.group(1)?.trim() ?? '';
    });
  }

  static String _processLists(String input) {
    return input.replaceAllMapped(
        RegExp(r'^(\s*[-*+]\s+)(.+)', multiLine: true), (match) {
      return '- ${match.group(2)?.trim()}';
    });
  }

  static String _removeHTMLAndComments(String input) {
    return input
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), '');
  }

  static String _processFormatting(String input) {
    return input
        .replaceAllMapped(
            RegExp(r'\*\*(.+?)\*\*'), (match) => match.group(1) ?? '')
        .replaceAllMapped(RegExp(r'_(.+?)_'), (match) => match.group(1) ?? '')
        .replaceAllMapped(RegExp(r'~(.+?)~'), (match) => match.group(1) ?? '');
  }

  static String _processBlocks(String input) {
    return input
        .replaceAllMapped(
            RegExp(r'^# (.+)', multiLine: true), (match) => '${match.group(1)}')
        .replaceAllMapped(RegExp(r'^## (.+)', multiLine: true),
            (match) => '${match.group(1)}')
        .replaceAllMapped(RegExp(r'^### (.+)', multiLine: true),
            (match) => '${match.group(1)}')
        .replaceAllMapped(RegExp(r'^#### (.+)', multiLine: true),
            (match) => '${match.group(1)}')
        .replaceAllMapped(RegExp(r'^##### (.+)', multiLine: true),
            (match) => '${match.group(1)}')
        .replaceAllMapped(RegExp(r'^###### (.+)', multiLine: true),
            (match) => '${match.group(1)}');
  }

  static String _processLinks(String input) {
    return input.replaceAllMapped(RegExp(r'\[(.*?)\]\((.*?)\)'), (match) {
      return match.group(1) ?? '';
    });
  }

  static String _processImages(String input) {
    return input.replaceAllMapped(RegExp(r'!\[(.*?)\]\((.*?)\)'), (match) {
      return match.group(1) ?? '';
    });
  }

  static String _processMath(String input) {
    return input.replaceAllMapped(
        RegExp(r'\$(.+?)\$'), (match) => match.group(1) ?? '');
  }

  static String _cleanupText(String input) {
    return input
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .replaceAll(RegExp(r'^\s+', multiLine: true), '')
        .trim();
  }

  static final Map<String, String> _htmlEntityMap = {
    '&lt;': '<',
    '&gt;': '>',
    '&amp;': '&',
    '&quot;': '"',
    '&apos;': "'",
  };
}
