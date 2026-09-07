import 'package:moodiary_i18n/moodiary_i18n.dart';

import 'export_doc.dart';

enum MarkdownDialect {
  commonMark,

  gfm,
}

enum MarkdownMediaMode {
  relative,

  absolute,
}

class MarkdownOptions {
  final MarkdownDialect dialect;

  final bool frontMatter;

  final bool includeTitle;

  final bool includeMetaLine;

  final MarkdownMediaMode mediaMode;

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

  static void _frontMatter(ExportDoc doc, StringBuffer buf) {
    buf.writeln('---');
    buf.writeln('id: ${doc.id}');
    buf.writeln('title: ${_yamlString(doc.title)}');
    buf.writeln('time: ${_isoWithOffset(doc.time)}');
    buf.writeln('mood: ${doc.mood.name}');
    if (doc.categoryName != null) {
      buf.writeln('category: ${_yamlString(doc.categoryName!)}');
    }
    final weather = doc.weather;
    final place = doc.place;
    if (weather != null) {
      buf.writeln(
        'weather: ${_yamlList([weather.icon, weather.temp ?? '', weather.text])}',
      );
    }
    if (place != null) {
      final tuple = [
        place.latitude.toString(),
        place.longitude.toString(),
        place.name,
      ];
      buf.writeln('position: ${_yamlList(tuple)}');
    }
    if (doc.tags.isNotEmpty) buf.writeln('tags: ${_yamlList(doc.tags)}');
    buf.writeln('---');
    buf.writeln();
  }

  static String _metaLine(ExportDoc doc) {
    final weather = doc.weather;
    final parts = <String>[
      _formatTime(doc.time),
      if (weather != null)
        [weather.icon, ?weather.temp, weather.text].join(' '),
      ?doc.place?.name,
      ?doc.categoryName,
    ];
    return parts.join(' · ');
  }

  static String _isoWithOffset(DateTime t) {
    if (t.isUtc) return t.toIso8601String();
    final offset = t.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.toIso8601String()}$sign${two(abs.inHours)}:${two(abs.inMinutes % 60)}';
  }

  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  static String _yamlString(String s) =>
      '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';

  static String _yamlList(List<String> items) =>
      '[${items.map(_yamlString).join(', ')}]';

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
        final label = kind == 'video'
            ? l10n.export.mediaVideo
            : l10n.export.mediaAudio;
        final target = o.mediaMode == .relative
            ? '${o.assetsDir}/$kind/$filename'
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

  static String _cellText(IrCell cell, MarkdownOptions o) {
    final inner = StringBuffer();
    _blocks(cell.children, inner, o, indent: '');
    return inner.toString().trim().replaceAll('\n', ' ').replaceAll('|', r'\|');
  }

  static String _image(IrBlock_Image img, MarkdownOptions o) {
    final alt = _escape(img.alt ?? '');
    if (img.isExternal) return '![$alt](${img.path})';
    final name = img.path.split(RegExp(r'[/\\]')).last;
    final target = switch (o.mediaMode) {
      .relative => '${o.assetsDir}/image/$name',
      .absolute => img.path,
    };
    return '![$alt]($target)';
  }

  static String _spans(List<IrSpan> spans, MarkdownOptions o) {
    final buf = StringBuffer();
    for (final span in spans) {
      buf.write(_span(span, o));
    }
    return buf.toString();
  }

  static String _span(IrSpan span, MarkdownOptions o) {
    if (span.diaryLinkId != null) return '[[${span.text}]]';

    if (span.code) {
      final fence = '`' * _inlineFenceLength(span.text);
      final pad = span.text.startsWith('`') || span.text.endsWith('`')
          ? ' '
          : '';
      return '$fence$pad${span.text}$pad$fence';
    }

    var text = _escape(span.text).replaceAll('\n', '\\\n');

    if (span.bold) text = '**$text**';
    if (span.italic) text = '*$text*';
    if (span.strike && o.dialect == .gfm) text = '~~$text~~';
    if (span.underline) text = '<u>$text</u>';
    if (span.href != null) text = '[$text](${_escapeUrl(span.href!)})';
    return text;
  }

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

  static void _writeIndented(StringBuffer buf, String text, String indent) {
    if (indent.isEmpty) {
      buf.writeln(text);
      return;
    }
    for (final line in text.split('\n')) {
      buf.writeln('$indent$line');
    }
  }

  static List<String> _lines(String text) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) return const [];
    return trimmed.split('\n');
  }
}
