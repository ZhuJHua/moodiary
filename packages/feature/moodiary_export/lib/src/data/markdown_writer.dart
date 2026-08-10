import 'export_doc.dart';

enum MarkdownDialect {
  /// 纯 CommonMark：表格降级为缩进代码块前的纯文本行，任务列表降级为普通列表。
  commonMark,

  /// GitHub 风味：表格、任务列表、删除线按 GFM 语法写。
  gfm,
}

enum MarkdownMediaMode {
  /// `./assets/xxx.jpg` —— 调用方负责把文件真的拷到 assets 目录。
  relative,

  /// 绝对路径，只在本机有意义。
  absolute,
}

class MarkdownOptions {
  final MarkdownDialect dialect;

  /// 写 YAML front matter（id / 时间 / 分类 / 天气 / 心情 / 位置 / 标签）。
  /// 导回来时靠它还原元数据 —— 正文本身表达不了这些。
  final bool frontMatter;

  /// 把标题写成一级标题。关掉适合「每篇一个文件、文件名即标题」的场景。
  final bool includeTitle;

  /// 在正文前写一行日期/天气/位置摘要（给人看的，不参与导入）。
  final bool includeMetaLine;

  final MarkdownMediaMode mediaMode;

  /// [MarkdownMediaMode.relative] 下的资源目录名。
  final String assetsDir;

  const MarkdownOptions({
    this.dialect = .gfm,
    this.frontMatter = true,
    this.includeTitle = true,
    this.includeMetaLine = false,
    this.mediaMode = .relative,
    this.assetsDir = 'assets',
  });
}

/// [ExportDoc] → Markdown 文本。
///
/// 与 [MarkdownToTiptap] 互为反向但**不无损**：markdown 没有语法能表达 diaryLink 的目标 id、
/// image 的 widthPercent、表格的合并与对齐，这几项在这里降级。front matter 兜住的是文档级
/// 元数据，不是正文里丢的那些。
class MarkdownWriter {
  const MarkdownWriter._();

  static String write(
    ExportDoc doc, [
    MarkdownOptions options = const MarkdownOptions(),
  ]) {
    final buf = StringBuffer();

    if (options.frontMatter) {
      _frontMatter(doc, buf);
    }
    if (options.includeTitle && doc.title.isNotEmpty) {
      buf.writeln('# ${_escape(doc.title)}');
      buf.writeln();
    }
    if (options.includeMetaLine) {
      final meta = _metaLine(doc);
      if (meta.isNotEmpty) {
        buf.writeln('> $meta');
        buf.writeln();
      }
    }

    _blocks(doc.blocks, buf, options, indent: '');

    return buf.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trimRight();
  }

  // ---------------------------------------------------------------- meta

  static void _frontMatter(ExportDoc doc, StringBuffer buf) {
    buf.writeln('---');
    buf.writeln('id: ${doc.id}');
    buf.writeln('title: ${_yamlString(doc.title)}');
    buf.writeln('time: ${doc.time.toIso8601String()}');
    buf.writeln('mood: ${doc.mood}');
    if (doc.categoryName != null) {
      buf.writeln('category: ${_yamlString(doc.categoryName!)}');
    }
    if (doc.weather.isNotEmpty) {
      buf.writeln('weather: ${_yamlList(doc.weather)}');
    }
    if (doc.position.isNotEmpty) {
      buf.writeln('position: ${_yamlList(doc.position)}');
    }
    if (doc.tags.isNotEmpty) buf.writeln('tags: ${_yamlList(doc.tags)}');
    buf.writeln('---');
    buf.writeln();
  }

  static String _metaLine(ExportDoc doc) {
    final parts = <String>[
      _formatTime(doc.time),
      if (doc.weather.isNotEmpty) doc.weather.join(' '),
      if (doc.position.isNotEmpty) doc.position.last,
      ?doc.categoryName,
    ];
    return parts.join(' · ');
  }

  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  /// YAML 标量：一律加引号并转义，避免标题里的 `:` `#` `-` 把结构写坏。
  static String _yamlString(String s) =>
      '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';

  static String _yamlList(List<String> items) =>
      '[${items.map(_yamlString).join(', ')}]';

  // -------------------------------------------------------------- blocks

  /// [tight] 用于列表项内部：段落与紧随其后的嵌套列表之间不留空行，否则整个列表会被
  /// CommonMark 判定为 loose list，渲染出多余的段落间距。顶层不能这么做 —— 段落与列表
  /// 之间少了空行，列表可能被当作段落的延续行吞掉。
  static void _blocks(
    List<IrBlock> blocks,
    StringBuffer buf,
    MarkdownOptions o, {
    required String indent,
    bool tight = false,
  }) {
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final next = i + 1 < blocks.length ? blocks[i + 1] : null;
      final skipBlank =
          tight && block is IrBlock_Paragraph && next is IrBlock_List;
      _block(block, buf, o, indent: indent, skipTrailingBlank: skipBlank);
    }
  }

  static void _block(
    IrBlock block,
    StringBuffer buf,
    MarkdownOptions o, {
    required String indent,
    bool skipTrailingBlank = false,
  }) {
    switch (block) {
      case IrBlock_Paragraph(:final spans):
        final text = _spans(spans, o);
        if (text.trim().isEmpty) {
          buf.writeln();
          return;
        }
        _writeIndented(buf, text, indent);
        if (!skipTrailingBlank) buf.writeln();

      case IrBlock_Heading(:final level, :final spans):
        _writeIndented(buf, '${'#' * level} ${_spans(spans, o)}', indent);
        buf.writeln();

      case IrBlock_Quote(:final children):
        final inner = StringBuffer();
        _blocks(children, inner, o, indent: '');
        for (final line in _lines(inner.toString())) {
          buf.writeln(line.isEmpty ? '$indent>' : '$indent> $line');
        }
        buf.writeln();

      case IrBlock_Code(:final text, :final language):
        // 正文里出现 ``` 时用更长的围栏，否则代码块会被提前关掉。
        final fence = '`' * _fenceLength(text);
        buf.writeln('$indent$fence${language ?? ''}');
        for (final line in text.split('\n')) {
          buf.writeln('$indent$line');
        }
        buf.writeln('$indent$fence');
        buf.writeln();

      case IrBlock_Divider():
        buf.writeln('$indent---');
        buf.writeln();

      case IrBlock_List():
        _list(block, buf, o, indent: indent);
        buf.writeln();

      case IrBlock_Image():
        _writeIndented(buf, _image(block, o), indent);
        buf.writeln();

      case IrBlock_Media(:final kind, :final filename):
        final label = kind == 'video' ? '视频' : '音频';
        final target = o.mediaMode == .relative
            ? '${o.assetsDir}/$filename'
            : filename;
        _writeIndented(buf, '[$label：$filename]($target)', indent);
        buf.writeln();

      case IrBlock_Table(:final rows):
        _table(rows, buf, o, indent: indent);
        buf.writeln();
    }
  }

  static void _list(
    IrBlock_List list,
    StringBuffer buf,
    MarkdownOptions o, {
    required String indent,
  }) {
    final gfm = o.dialect == .gfm;
    var number = list.start;

    for (final item in list.items) {
      final marker = list.ordered ? '${number++}.' : '-';
      final box = (item.checked != null && gfm)
          ? (item.checked! ? '[x] ' : '[ ] ')
          : '';

      // 首块与标记同行，其余块按标记宽度缩进，保持嵌套结构。
      final childIndent = indent + ' ' * (marker.length + 1);
      final inner = StringBuffer();
      _blocks(item.children, inner, o, indent: '', tight: true);
      final lines = _lines(inner.toString());

      if (lines.isEmpty) {
        buf.writeln('$indent$marker $box');
        continue;
      }
      buf.writeln('$indent$marker $box${lines.first}');
      for (final line in lines.skip(1)) {
        buf.writeln(line.isEmpty ? '' : '$childIndent$line');
      }
    }
  }

  static void _table(
    List<IrRow> rows,
    StringBuffer buf,
    MarkdownOptions o, {
    required String indent,
  }) {
    if (rows.isEmpty) return;

    // GFM 简单表没有合并单元格：colspan/rowspan 只能丢，内容保留在起始格。
    if (o.dialect != .gfm) {
      for (final row in rows) {
        final cells = [for (final c in row.cells) _cellText(c, o)];
        _writeIndented(buf, cells.join('\t'), indent);
      }
      return;
    }

    final width = rows.fold<int>(
      0,
      (m, r) => r.cells.length > m ? r.cells.length : m,
    );
    final header = rows.first;
    final headerCells = [
      for (var i = 0; i < width; i++)
        i < header.cells.length ? _cellText(header.cells[i], o) : '',
    ];
    buf.writeln('$indent| ${headerCells.join(' | ')} |');
    buf.writeln('$indent|${List.filled(width, ' --- ').join('|')}|');
    for (final row in rows.skip(1)) {
      final cells = [
        for (var i = 0; i < width; i++)
          i < row.cells.length ? _cellText(row.cells[i], o) : '',
      ];
      buf.writeln('$indent| ${cells.join(' | ')} |');
    }
  }

  /// 单元格压成单行：表格语法里换行会把行结构打断，`|` 必须转义。
  static String _cellText(IrCell cell, MarkdownOptions o) {
    final inner = StringBuffer();
    _blocks(cell.children, inner, o, indent: '');
    return inner.toString().trim().replaceAll('\n', ' ').replaceAll('|', r'\|');
  }

  static String _image(IrBlock_Image img, MarkdownOptions o) {
    final alt = _escape(img.alt ?? '');
    if (img.external_) return '![$alt](${img.path})';
    final name = img.path.split(RegExp(r'[/\\]')).last;
    final target = switch (o.mediaMode) {
      .relative => '${o.assetsDir}/$name',
      .absolute => img.path,
    };
    return '![$alt]($target)';
  }

  // -------------------------------------------------------------- inline

  static String _spans(List<IrSpan> spans, MarkdownOptions o) {
    final buf = StringBuffer();
    for (final span in spans) {
      buf.write(_span(span, o));
    }
    return buf.toString();
  }

  static String _span(IrSpan span, MarkdownOptions o) {
    // 双链没有 markdown 对应语法：写成 wiki 链接，目标 id 丢失（导回来只能按标题再找）。
    if (span.diaryLinkId != null) return '[[${span.text}]]';

    // 行内代码里的内容不转义（转义反而会写进代码里），只需保证围栏比内容里最长的反引号长。
    if (span.code) {
      final fence = '`' * _inlineFenceLength(span.text);
      final pad = span.text.startsWith('`') || span.text.endsWith('`')
          ? ' '
          : '';
      return '$fence$pad${span.text}$pad$fence';
    }

    // 硬换行：CommonMark 的反斜杠形式，比行尾两个空格可见、也不会被格式化工具吃掉。
    var text = _escape(span.text).replaceAll('\n', '\\\n');

    if (span.bold) text = '**$text**';
    if (span.italic) text = '*$text*';
    if (span.strike && o.dialect == .gfm) text = '~~$text~~';
    if (span.underline) text = '<u>$text</u>';
    if (span.href != null) text = '[$text](${_escapeUrl(span.href!)})';
    return text;
  }

  /// 正文转义。只转会引发语法歧义的字符 —— 全量转义会让导出的 md 满屏反斜杠。
  static String _escape(String text) {
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      switch (ch) {
        case r'\':
        case '`':
        case '*':
        case '_':
        case '[':
        case ']':
        case '<':
          buf.write('\\$ch');
        default:
          buf.write(ch);
      }
    }
    return buf.toString();
  }

  /// URL 里的空格与括号会截断链接语法。
  static String _escapeUrl(String url) =>
      url.replaceAll(' ', '%20').replaceAll('(', '%28').replaceAll(')', '%29');

  static int _fenceLength(String text) {
    var longest = 0;
    for (final m in RegExp(r'`+').allMatches(text)) {
      if (m.group(0)!.length > longest) longest = m.group(0)!.length;
    }
    return longest < 3 ? 3 : longest + 1;
  }

  static int _inlineFenceLength(String text) {
    var longest = 0;
    for (final m in RegExp(r'`+').allMatches(text)) {
      if (m.group(0)!.length > longest) longest = m.group(0)!.length;
    }
    return longest + 1;
  }

  // --------------------------------------------------------------- utils

  static void _writeIndented(StringBuffer buf, String text, String indent) {
    if (indent.isEmpty) {
      buf.writeln(text);
      return;
    }
    for (final line in text.split('\n')) {
      buf.writeln('$indent$line');
    }
  }

  /// 去掉尾部空行后按行切分 —— 供引用块与列表项做二次缩进。
  static List<String> _lines(String text) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) return const [];
    return trimmed.split('\n');
  }
}
