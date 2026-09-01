/// 把 Markdown 转「纯文本」，用于卡片预览、字数统计与搜索分词（去语法留文字，
/// 不追求 CommonMark 严格一致）。处理顺序经过编排以避免规则相互误伤，见 [convert]。
class MarkdownConverter {
  const MarkdownConverter._();

  static String convert(String markdown) {
    if (markdown.isEmpty) return '';
    var text = _normalizeLineEndings(markdown);
    text = _protectEscapes(text); // 转义字符先入占位符，最后再还原
    text = _stripFencedCode(text);
    text = _stripHtml(text);
    text = _stripImages(text); // 必须在链接之前
    text = _stripLinks(text);
    text = _stripHeadings(text);
    text = _stripBlockquotes(text);
    text = _stripHorizontalRules(text); // 必须在列表之前（`- - -` 也像列表）
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

  /// 可被反斜杠转义的字符（CommonMark 标点 + 扩展的 `$`）。索引用作占位符偏移。
  static final List<String> _escapableChars = r'\`*_{}[]()#+-.!>~|$'.split('');

  /// 占位符区间起点：私有使用区，避免与正文字符冲突。
  static const int _puaBase = 0xE000;

  /// 把 `\X` 换成占位符，使后续规则看不到这些字面标记；行尾 `\`（硬换行）退化为换行。
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

  /// 去掉代码围栏标记行（``` / ~~~ 及其语言标识），保留围栏内的代码文本。
  static String _stripFencedCode(String s) => s.replaceAll(
    RegExp(r'^[ \t]*(?:```|~~~)[^\n]*$\n?', multiLine: true),
    '',
  );

  static String _stripHtml(String s) => s
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'<[^>]+>'), '');

  /// 图片：保留 alt 文本，丢弃 URL。moodiary 内嵌图片 alt 多为空，结果即为空串。
  static String _stripImages(String s) => s
      .replaceAllMapped(
        RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
        (m) => m.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'!\[([^\]]*)\]\[[^\]]*\]'),
        (m) => m.group(1) ?? '',
      );

  /// 链接：保留显示文本，丢弃 URL；自动链接 `<https://...>` 保留 URL 本身。
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

  /// 标题：去掉行首 `#`（需后跟空格或行尾，避免误伤 `#标签`）与可选的结尾 `#`；
  /// 顺带去掉 setext 标题的 `===` 下划线行（`---` 由分隔线规则处理）。
  static String _stripHeadings(String s) => s
      .replaceAll(RegExp(r'^[ \t]*#{1,6}(?:[ \t]+|$)', multiLine: true), '')
      .replaceAll(RegExp(r'[ \t]+#+[ \t]*$', multiLine: true), '')
      .replaceAll(RegExp(r'^[ \t]*={3,}[ \t]*$\n?', multiLine: true), '');

  /// 引用：去掉行首的 `>`（含嵌套 `> >`）。
  static String _stripBlockquotes(String s) =>
      s.replaceAll(RegExp(r'^[ \t]*(?:>[ \t]?)+', multiLine: true), '');

  /// 分隔线：整行的 `---` / `***` / `___`（3+，允许中间夹空格）整行删除。
  static String _stripHorizontalRules(String s) => s.replaceAll(
    RegExp(r'^[ \t]*([-*_])(?:[ \t]*\1){2,}[ \t]*$\n?', multiLine: true),
    '',
  );

  /// 列表：去掉行首的无序（`-`/`*`/`+`）或有序（`1.`/`1)`）标记，以及任务清单 `[ ]`/`[x]`。
  static String _stripListMarkers(String s) => s
      .replaceAll(
        RegExp(r'^[ \t]*(?:[-*+]|\d+[.)])[ \t]+', multiLine: true),
        '',
      )
      .replaceAll(RegExp(r'^[ \t]*\[[ xX]\][ \t]*', multiLine: true), '');

  /// 表格：去掉分隔行（`| --- | :--: |`），其余行去掉管道、单元格用两个空格连接。
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

  /// 强调：先三联（`***`/`___`）、再双联（`**`/`__`/`~~`）、最后单个（`*`/`_`），
  /// 保留内部文字。单个 `_` 用环视避免误伤 `snake_case` 这类词内下划线。
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

  /// 行内代码：去掉反引号，保留代码文本（双反引号优先）。
  static String _stripInlineCode(String s) => s
      .replaceAllMapped(RegExp(r'``([^`]+)``'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);

  /// 数学公式：去掉 `$$...$$` / `$...$` 定界符，保留公式源码作为文本。
  static String _stripMath(String s) => s
      .replaceAllMapped(
        RegExp(r'\$\$(.+?)\$\$', dotAll: true),
        (m) => m.group(1)!,
      )
      .replaceAllMapped(RegExp(r'\$(.+?)\$'), (m) => m.group(1)!);

  /// HTML 实体：命名实体查表，数字实体（`&#1234;` / `&#x1F;`）按码点解码。
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

  /// 收尾：去行尾空白、折叠多余空行、整体 trim。
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
