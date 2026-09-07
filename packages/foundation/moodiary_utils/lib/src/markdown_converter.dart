class MarkdownConverter {
  const MarkdownConverter._();

  static String convert(String markdown) {
    if (markdown.isEmpty) return '';
    var text = _normalizeLineEndings(markdown);
    text = _protectEscapes(text);
    text = _stripFencedCode(text);
    text = _stripHtml(text);
    text = _stripImages(text);
    text = _stripLinks(text);
    text = _stripHeadings(text);
    text = _stripBlockquotes(text);
    text = _stripHorizontalRules(text);
    text = _stripListMarkers(text);
    text = _stripTables(text);
    text = _stripEmphasis(text);
    text = _stripInlineCode(text);
    text = _stripMath(text);
    text = _decodeHtmlEntities(text);
    text = _restoreEscapes(text);
    return _cleanup(text);
  }

  static String _normalizeLineEndings(String s) =>
      s.replaceAll(RegExp(r'\r\n?'), '\n');

  static final List<String> _escapableChars = r'\`*_{}[]()#+-.!>~|$'.split('');

  static const int _puaBase = 0xE000;

  static String _protectEscapes(String s) =>
      s.replaceAllMapped(RegExp(r'\\(.)', dotAll: true), (m) {
        final ch = m.group(1)!;
        if (ch == '\n') return '\n';
        final idx = _escapableChars.indexOf(ch);
        return idx < 0 ? m.group(0)! : String.fromCharCode(_puaBase + idx);
      });

  static String _restoreEscapes(String s) =>
      s.replaceAllMapped(RegExp(r'[-]'), (m) {
        final idx = m.group(0)!.codeUnitAt(0) - _puaBase;
        return (idx >= 0 && idx < _escapableChars.length)
            ? _escapableChars[idx]
            : m.group(0)!;
      });

  static String _stripFencedCode(String s) => s.replaceAll(
    RegExp(r'^[ \t]*(?:```|~~~)[^\n]*$\n?', multiLine: true),
    '',
  );

  static String _stripHtml(String s) => s
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'<[^>]+>'), '');

  static String _stripImages(String s) => s
      .replaceAllMapped(
        RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
        (m) => m.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'!\[([^\]]*)\]\[[^\]]*\]'),
        (m) => m.group(1) ?? '',
      );

  static String _stripLinks(String s) => s
      .replaceAllMapped(
        RegExp(r'\[([^\]]*)\]\([^)]*\)'),
        (m) => m.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'\[([^\]]*)\]\[[^\]]*\]'),
        (m) => m.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'<((?:https?|mailto):[^>\s]+)>'),
        (m) => m.group(1) ?? '',
      );

  static String _stripHeadings(String s) => s
      .replaceAll(RegExp(r'^[ \t]*#{1,6}(?:[ \t]+|$)', multiLine: true), '')
      .replaceAll(RegExp(r'[ \t]+#+[ \t]*$', multiLine: true), '')
      .replaceAll(RegExp(r'^[ \t]*={3,}[ \t]*$\n?', multiLine: true), '');

  static String _stripBlockquotes(String s) =>
      s.replaceAll(RegExp(r'^[ \t]*(?:>[ \t]?)+', multiLine: true), '');

  static String _stripHorizontalRules(String s) => s.replaceAll(
    RegExp(r'^[ \t]*([-*_])(?:[ \t]*\1){2,}[ \t]*$\n?', multiLine: true),
    '',
  );

  static String _stripListMarkers(String s) => s
      .replaceAll(
        RegExp(r'^[ \t]*(?:[-*+]|\d+[.)])[ \t]+', multiLine: true),
        '',
      )
      .replaceAll(RegExp(r'^[ \t]*\[[ xX]\][ \t]*', multiLine: true), '');

  static String _stripTables(String s) => s
      .replaceAll(
        RegExp(
          r'^[ \t]*\|?[ \t]*:?-{2,}:?[ \t]*(?:\|[ \t]*:?-{2,}:?[ \t]*)*\|?[ \t]*$\n?',
          multiLine: true,
        ),
        '',
      )
      .replaceAllMapped(RegExp(r'^[ \t]*\|(.+)\|[ \t]*$', multiLine: true), (
        m,
      ) {
        return m
            .group(1)!
            .split('|')
            .map((cell) => cell.trim())
            .where((cell) => cell.isNotEmpty)
            .join('  ');
      });

  static String _stripEmphasis(String s) => s
      .replaceAllMapped(RegExp(r'\*\*\*(.+?)\*\*\*'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'___(.+?)___'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'\*([^*\n]+)\*'), (m) => m.group(1)!)
      .replaceAllMapped(
        RegExp(r'(?<!\w)_([^_\n]+)_(?!\w)'),
        (m) => m.group(1)!,
      );

  static String _stripInlineCode(String s) => s
      .replaceAllMapped(RegExp(r'``([^`]+)``'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);

  static String _stripMath(String s) => s
      .replaceAllMapped(
        RegExp(r'\$\$(.+?)\$\$', dotAll: true),
        (m) => m.group(1)!,
      )
      .replaceAllMapped(RegExp(r'\$(.+?)\$'), (m) => m.group(1)!);

  static String _decodeHtmlEntities(String s) => s.replaceAllMapped(
    RegExp(r'&(#\d+|#[xX][0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);'),
    (m) {
      final whole = m.group(0)!;
      final named = _htmlEntityMap[whole];
      if (named != null) return named;
      final body = m.group(1)!;
      if (body.startsWith('#x') || body.startsWith('#X')) {
        final code = int.tryParse(body.substring(2), radix: 16);
        if (code != null) return String.fromCharCode(code);
      } else if (body.startsWith('#')) {
        final code = int.tryParse(body.substring(1));
        if (code != null) return String.fromCharCode(code);
      }
      return whole;
    },
  );

  static String _cleanup(String s) => s
      .replaceAll(RegExp(r'[ \t]+$', multiLine: true), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  static const Map<String, String> _htmlEntityMap = {
    '&lt;': '<',
    '&gt;': '>',
    '&amp;': '&',
    '&quot;': '"',
    '&apos;': "'",
    '&nbsp;': ' ',
  };
}
