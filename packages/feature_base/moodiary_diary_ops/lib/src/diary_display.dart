/// Diary projections shared by the assistant tools and the MCP catalog:
/// time rendering, list summaries, category views and a Tiptap document to
/// Markdown or plain text walker.
///
/// Nothing here invents content: media only appears when the document itself
/// carries a media node, and a legacy (non Tiptap) diary is handed back as the
/// text it already is. Text runs are escaped so a document that contains
/// literal Markdown syntax survives a document → Markdown → document
/// round-trip.
library;

import 'dart:convert';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

/// Upper bound for one tool or resource payload. A model pays for every
/// character, and one huge diary must not flood a context window.
const int mcpResultChars = 100000;

/// Length of the `excerpt` field of a diary summary.
const int excerptChars = 200;

/// URI prefix of the single diary resource template.
const String diaryUriPrefix = 'moodiary://diary/';

/// How a link is projected in the plain-text and Markdown representations.
///
/// [uri] keeps the target: `[label](href)` in Markdown and `label (href)` in
/// plain text. [label] drops the target and leaves only the label, which is
/// what list previews want.
enum DiaryLinkStyle { uri, label }

/// The stored representation: ISO-8601 in UTC.
String isoUtc(DateTime time) => time.toUtc().toIso8601String();

/// Offset aware local time. Dart's own ISO-8601 output for a local instant omits
/// the offset, which would make two devices' timestamps ambiguous.
String isoLocal(DateTime time) {
  final local = time.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absolute = offset.abs();
  final hours = absolute.inHours.toString().padLeft(2, '0');
  final minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  return '${local.toIso8601String()}$sign$hours:$minutes';
}

/// Cuts [text] to [chars] code points and marks the cut with an ellipsis.
String truncate(String text, [int chars = mcpResultChars]) {
  if (text.length <= chars) return text;
  final runes = text.runes;
  if (runes.length <= chars) return text;
  return '${String.fromCharCodes(runes.take(chars))}…';
}

/// The plain body of [diary]: no Markdown syntax and media runs rendered as
/// `[image: name]` placeholders. A diary mention becomes
/// `label (moodiary://diary/<id>)` and an external link `text (href)`, so a
/// caller reading plain text can still follow a link.
String diaryToText(
  Diary diary, {
  DiaryLinkStyle linkStyle = DiaryLinkStyle.uri,
}) => switch (DiaryType.fromValue(diary.type)) {
  DiaryType.tiptap => _tiptapToText(diary, linkStyle),
  DiaryType.markdown ||
  DiaryType.richText => MediaMarkup.forModel(diary.contentText),
};

/// One line preview of the diary body, used by every list shaped result.
///
/// With [renderMarkdown] the preview is the Markdown body cut to
/// [excerptChars] instead, so headings and lists survive the cut; the plain
/// form collapses every run of whitespace to a single space and drops link
/// targets, because a preview is not a navigation surface.
String excerptOf(Diary diary, {bool renderMarkdown = false}) {
  if (renderMarkdown) return truncate(diaryToMarkdown(diary), excerptChars);
  final text = diaryToText(
    diary,
    linkStyle: DiaryLinkStyle.label,
  ).replaceAll(RegExp(r'\s+'), ' ');
  return truncate(text.trim(), excerptChars);
}

/// `#AARRGGBB`, or `null` when the category has no colour.
String? colorHex(int? argb) => argb == null
    ? null
    : '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// The list shaped projection a client sees for one diary.
///
/// [renderMarkdown] selects the `excerpt` projection: the one line plain
/// preview by default, the Markdown body cut to [excerptChars] when true.
Map<String, dynamic> diarySummary(
  Diary diary, {
  String? categoryName,
  bool renderMarkdown = false,
}) => {
  'id': diary.id,
  'title': diary.title,
  'time': isoUtc(diary.time),
  'timeLocal': isoLocal(diary.time),
  'lastModified': isoUtc(diary.lastModified),
  'categoryId': diary.categoryId,
  'categoryName': categoryName,
  'mood': diary.mood?.name,
  'tags': diary.tags,
  'excerpt': excerptOf(diary, renderMarkdown: renderMarkdown),
  'show': diary.show,
};

/// The tiptap body of [diary] as Markdown. Legacy diaries are not converted:
/// a Markdown diary already holds Markdown, a rich text one only has its text.
String diaryToMarkdown(
  Diary diary, {
  DiaryLinkStyle linkStyle = DiaryLinkStyle.uri,
}) => switch (DiaryType.fromValue(diary.type)) {
  DiaryType.tiptap => tiptapToMarkdown(diary.content, linkStyle: linkStyle),
  DiaryType.markdown => diary.content,
  DiaryType.richText => diaryToText(diary, linkStyle: linkStyle),
};

/// Renders a stored Tiptap document as Markdown.
///
/// Handles the node types the app's editor writes: paragraphs, headings, bullet
/// and ordered lists, task lists, block quotes, code blocks, horizontal rules,
/// GFM pipe tables, links, diary mentions and media. Unknown blocks are
/// descended into so no text is lost; media is rendered from the node that is
/// actually in the document.
///
/// [DiaryLinkStyle.label] degrades a diary mention to its label text, without
/// the `moodiary://diary/<id>` URI.
String tiptapToMarkdown(
  String content, {
  DiaryLinkStyle linkStyle = DiaryLinkStyle.uri,
}) {
  final parsed = TiptapContent.parse(content);
  if (!parsed.isDoc) return content;
  final Object? decoded;
  try {
    decoded = jsonDecode(parsed.normalized);
  } on FormatException {
    return content;
  }
  if (decoded is! Map) return content;
  final out = StringBuffer();
  _blocks(decoded['content'], out, linkStyle);
  return out.toString().trim();
}

/// Plain text derivation of a Tiptap body, mirroring the stored `contentText`
/// but keeping link targets. Anything that is not a document falls back to the
/// text the row already carries.
String _tiptapToText(Diary diary, DiaryLinkStyle linkStyle) {
  final parsed = TiptapContent.parse(diary.content);
  if (!parsed.isDoc) return MediaMarkup.forModel(diary.contentText);
  final Object? decoded;
  try {
    decoded = jsonDecode(parsed.normalized);
  } on FormatException {
    return MediaMarkup.forModel(diary.contentText);
  }
  if (decoded is! Map) return MediaMarkup.forModel(diary.contentText);

  final buf = StringBuffer();
  var first = true;
  void separate() {
    if (first) {
      first = false;
    } else {
      buf.write('\n');
    }
  }

  // Adjacent text runs that share one link are one run: the parser splits an
  // escaped label into several text nodes, and a target per node would repeat
  // the URI.
  final pendingText = <String>[];
  String? pendingHref;
  void flushText() {
    if (pendingText.isEmpty) return;
    buf.write(pendingText.join());
    if (linkStyle == DiaryLinkStyle.uri &&
        pendingHref != null &&
        pendingHref!.isNotEmpty) {
      buf.write(' ($pendingHref)');
    }
    pendingText.clear();
    pendingHref = null;
  }

  void walk(Object? node) {
    if (node is! Map) return;
    switch (node['type']) {
      case 'text':
        final text = node['text'];
        if (text is! String) return;
        final body = MediaMarkup.strip(text);
        if (body.isEmpty) return;
        final href = _linkHref(node['marks']);
        if (pendingText.isNotEmpty && href != pendingHref) flushText();
        pendingText.add(body);
        pendingHref = href;
      case 'hardBreak':
        flushText();
        buf.write('\n');
      case 'diaryLink':
        flushText();
        final attrs = node['attrs'];
        final id = attrs is Map ? attrs['id'] : null;
        buf.write(MediaMarkup.strip(_diaryLinkLabel(attrs)));
        if (linkStyle == DiaryLinkStyle.uri && id is String && id.isNotEmpty) {
          buf.write(' ($diaryUriPrefix$id)');
        }
      case 'horizontalRule':
        flushText();
        return;
      default:
        flushText();
        final kind = _mediaKindOf(node['type']);
        if (kind != null) {
          final name = _mediaName(node['attrs']);
          if (name.isEmpty) return;
          separate();
          buf.write(MediaMarkup.mark(kind, name));
          return;
        }
        final content = node['content'];
        if (_textblocks.contains(node['type']) || _hasTextChild(content)) {
          separate();
        }
        if (content is List) content.forEach(walk);
    }
  }

  final content = decoded['content'];
  if (content is List) content.forEach(walk);
  flushText();
  return MediaMarkup.forModel(buf.toString());
}

void _blocks(Object? nodes, StringBuffer out, DiaryLinkStyle style) {
  if (nodes is! List) return;
  for (final node in nodes) {
    if (node is! Map) continue;
    final block = _block(node, style);
    if (block == null || block.isEmpty) continue;
    if (out.isNotEmpty) out.write('\n\n');
    out.write(block);
  }
}

String? _block(Map<dynamic, dynamic> node, DiaryLinkStyle style) {
  final attrs = node['attrs'];
  switch (node['type']) {
    case 'paragraph':
      final text = _escapeBlockStarts(_inline(node['content'], style));
      return text.trim().isEmpty ? null : text;
    case 'heading':
      final raw = attrs is Map ? attrs['level'] : null;
      final level = raw is int ? raw.clamp(1, 6) : 1;
      final text = _inline(node['content'], style).trim();
      return text.isEmpty ? null : '${'#' * level} $text';
    case 'codeBlock':
      final language = attrs is Map && attrs['language'] is String
          ? attrs['language'] as String
          : '';
      return '```$language\n${_plainInline(node['content'])}\n```';
    case 'blockquote':
      final inner = StringBuffer();
      _blocks(node['content'], inner, style);
      final text = inner.toString().trim();
      if (text.isEmpty) return null;
      return [
        for (final line in text.split('\n')) line.isEmpty ? '>' : '> $line',
      ].join('\n');
    case 'bulletList':
      return _list(node['content'], style, ordered: false);
    case 'orderedList':
      final start = attrs is Map && attrs['start'] is int
          ? attrs['start'] as int
          : 1;
      return _list(node['content'], style, ordered: true, start: start);
    case 'taskList':
      return _listLines(
        node['content'],
        style,
        itemType: 'taskItem',
        marker: (_, item) {
          final itemAttrs = item['attrs'];
          return itemAttrs is Map && itemAttrs['checked'] == true
              ? '- [x]'
              : '- [ ]';
        },
      );
    case 'table':
      return _table(node['content'], style);
    case 'horizontalRule':
      return '---';
    case 'image' || 'video' || 'audio' || 'attachment':
      return _media(node['type'], attrs);
    default:
      final inner = StringBuffer();
      _blocks(node['content'], inner, style);
      return inner.isEmpty ? null : inner.toString();
  }
}

String? _list(
  Object? items,
  DiaryLinkStyle style, {
  required bool ordered,
  int start = 1,
}) => _listLines(
  items,
  style,
  itemType: 'listItem',
  marker: (index, _) => ordered ? '${start + index}.' : '-',
);

/// Shared renderer for bullet, ordered and task lists: a marker followed by the
/// item body, nested blocks indented two spaces under the marker.
String? _listLines(
  Object? items,
  DiaryLinkStyle style, {
  required String itemType,
  required String Function(int index, Map<dynamic, dynamic> item) marker,
}) {
  if (items is! List) return null;
  final lines = <String>[];
  var index = 0;
  for (final item in items) {
    if (item is! Map || item['type'] != itemType) continue;
    final inner = StringBuffer();
    _blocks(item['content'], inner, style);
    final text = inner.toString().trim();
    if (text.isEmpty) continue;
    final attrs = item['attrs'];
    final depth = attrs is Map ? attrs['depth'] : null;
    final indent = depth is int && depth > 0 ? '  ' * depth : '';
    final body = text.split('\n');
    lines.add('$indent${marker(index, item)} ${body.first}');
    for (final line in body.skip(1)) {
      lines.add(line.isEmpty ? '' : '$indent  $line');
    }
    index++;
  }
  return lines.isEmpty ? null : lines.join('\n');
}

/// GFM pipe table: the first row becomes the header, its cell count fixes the
/// `| --- |` separator, and every later row is padded to the same width.
String? _table(Object? rows, DiaryLinkStyle style) {
  if (rows is! List) return null;
  final rendered = <List<String>>[];
  for (final row in rows) {
    if (row is! Map || row['type'] != 'tableRow') continue;
    final cells = <String>[];
    final content = row['content'];
    if (content is List) {
      for (final cell in content) {
        if (cell is! Map) continue;
        final type = cell['type'];
        if (type != 'tableCell' && type != 'tableHeader') continue;
        cells.add(_tableCell(cell['content'], style));
      }
    }
    if (cells.isNotEmpty) rendered.add(cells);
  }
  if (rendered.isEmpty) return null;
  final header = rendered.first;

  final out = StringBuffer();
  void line(List<String> cells) {
    out.write('| ${cells.join(' | ')} |');
  }

  line(header);
  out.write('\n');
  line([for (final _ in header) '---']);
  for (final row in rendered.skip(1)) {
    final cells = row.take(header.length).toList();
    while (cells.length < header.length) {
      cells.add('');
    }
    out.write('\n');
    line(cells);
  }
  return out.toString();
}

/// Cell content is inline only: block structure does not exist inside a GFM
/// cell, so every block is flattened and line breaks become spaces.
String _tableCell(Object? content, DiaryLinkStyle style) {
  if (content is! List) return '';
  final parts = <String>[];
  for (final block in content) {
    if (block is! Map) continue;
    final text = _inline(
      block['content'],
      style,
    ).replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
    if (text.isNotEmpty) parts.add(text);
  }
  return parts.join(' ');
}

String? _media(Object? type, Object? attrs) {
  if (attrs is! Map) return null;
  final src = attrs['src'];
  if (src is! String || src.isEmpty) return null;
  final name = attrs['name'];
  final label = _escapeMarkdown(name is String && name.isNotEmpty ? name : src);
  return switch (type) {
    'image' => '![$label]($src)',
    'attachment' => '[$label]($src)',
    _ => '[$type: $label]($src)',
  };
}

String _inline(Object? nodes, DiaryLinkStyle style) {
  final buf = StringBuffer();
  if (nodes is! List) return '';

  // The parser splits an escaped label into several text nodes; rendering each
  // one with its own wrappers would turn one link into several. Adjacent text
  // nodes with identical marks are therefore rendered as one run.
  final run = <Map<dynamic, dynamic>>[];
  List<dynamic>? runMarks;
  String? runSignature;
  void flushRun() {
    if (run.isEmpty) return;
    buf.write(
      _marked({
        'type': 'text',
        'text': run.map((node) => node['text'] as String).join(),
        'marks': ?runMarks,
      }),
    );
    run.clear();
    runMarks = null;
    runSignature = null;
  }

  for (final node in nodes) {
    if (node is! Map) continue;
    if (node['type'] == 'text' && node['text'] is String) {
      final marks = node['marks'];
      final signature = jsonEncode(marks);
      if (run.isNotEmpty && signature != runSignature) flushRun();
      runSignature = signature;
      runMarks = marks is List ? marks : null;
      run.add(node);
      continue;
    }
    flushRun();
    switch (node['type']) {
      case 'hardBreak':
        buf.write('  \n');
      case 'diaryLink':
        buf.write(_diaryLink(node['attrs'], style));
      case 'image' || 'video' || 'audio' || 'attachment':
        buf.write(_media(node['type'], node['attrs']) ?? '');
      default:
        buf.write(_inline(node['content'], style));
    }
  }
  flushRun();
  return buf.toString();
}

String _diaryLink(Object? attrs, DiaryLinkStyle style) {
  final id = attrs is Map ? attrs['id'] : null;
  final label = attrs is Map ? attrs['label'] : null;
  final raw = label is String && label.isNotEmpty ? label : '$id';
  final text = _escapeMarkdown(raw);
  if (style == DiaryLinkStyle.label || id is! String || id.isEmpty) {
    return text;
  }
  return '[$text]($diaryUriPrefix$id)';
}

String _marked(Map<dynamic, dynamic> node) {
  final raw = node['text'];
  if (raw is! String || raw.isEmpty) return '';
  final marks = node['marks'];
  var bold = false;
  var italic = false;
  var code = false;
  var strike = false;
  var highlight = false;
  var underline = false;
  String? href;
  if (marks is List) {
    for (final mark in marks) {
      if (mark is! Map) continue;
      switch (mark['type']) {
        case 'bold' || 'strong':
          bold = true;
        case 'italic' || 'em':
          italic = true;
        case 'code':
          code = true;
        case 'strike':
          strike = true;
        case 'highlight':
          highlight = true;
        case 'underline':
          underline = true;
        case 'link':
          final attrs = mark['attrs'];
          if (attrs is Map && attrs['href'] is String) {
            href = attrs['href'] as String;
          }
      }
    }
  }
  var text = code ? _codeSpan(raw) : _escapeMarkdown(raw, highlight: highlight);
  if (bold) text = '**$text**';
  if (italic) text = '*$text*';
  if (strike) text = '~~$text~~';
  if (highlight) text = '==$text==';
  if (underline) text = '<u>$text</u>';
  if (href != null && href.isNotEmpty) text = '[$text]($href)';
  return text;
}

/// Characters Markdown would read as syntax inside a text run.
///
/// The app parses Markdown as CommonMark/GFM, where a backslash turns the next
/// ASCII punctuation character into literal text, so `\*` parses back to `*`.
/// Escaping them keeps a user's literal `**`, `#`, `` ` `` or `|` from turning
/// into formatting on the next read.
const Set<String> _markdownSyntaxChars = {
  '\\',
  '`',
  '*',
  '_',
  '~',
  '=',
  '[',
  ']',
  '|',
  '#',
  '<',
  '>',
};

/// Escapes [text] for a Markdown text run.
///
/// Inside a highlight mark `=` is left alone: `==` is the delimiter the
/// renderer itself emits, and escaping it would break the mark the wrapper
/// opens. A literal `==` in highlighted text therefore cannot be represented,
/// which is a known limit of the `==` syntax.
String _escapeMarkdown(String text, {bool highlight = false}) {
  final buf = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (_markdownSyntaxChars.contains(char) && !(highlight && char == '=')) {
      buf.write(r'\');
    }
    buf.write(char);
  }
  return buf.toString();
}

/// Escapes a paragraph line that would otherwise start a list. Heading,
/// quote, emphasis and thematic-break markers are already escaped by
/// [_escapeMarkdown]; `-`, `+` and `1.` only matter at the start of a line.
String _escapeBlockStarts(String text) =>
    text.split('\n').map(_escapeBlockStart).join('\n');

String _escapeBlockStart(String line) {
  final lead = RegExp(r'^ {0,3}').firstMatch(line)!.group(0)!;
  final rest = line.substring(lead.length);
  if (rest.isEmpty) return line;
  if ((rest[0] == '-' || rest[0] == '+') &&
      (rest.length == 1 || rest[1] == ' ')) {
    return '$lead\\$rest';
  }
  // Three or more dashes on a line would become a thematic break; a setext
  // heading underline with `=` is already escaped by [_escapeMarkdown].
  if (rest.length >= 3 && rest.startsWith('---')) return '$lead\\$rest';
  final ordered = RegExp(r'^(\d{1,9})([.)])(?= |$)').firstMatch(rest);
  if (ordered != null) {
    return '$lead${ordered[1]}\\${rest.substring(ordered[1]!.length)}';
  }
  return line;
}

/// A code span keeps its text literal, so only the backtick fence needs work:
/// the fence is one backtick longer than the longest run in the content, and
/// content that starts or ends with a backtick is padded so CommonMark strips
/// the padding instead of a real character.
String _codeSpan(String text) {
  var longest = 0;
  for (final match in RegExp(r'`+').allMatches(text)) {
    if (match.group(0)!.length > longest) longest = match.group(0)!.length;
  }
  final fence = '`' * (longest + 1);
  final body = text.startsWith('`') || text.endsWith('`') ? ' $text ' : text;
  return '$fence$body$fence';
}

String? _linkHref(Object? marks) {
  if (marks is! List) return null;
  String? href;
  for (final mark in marks) {
    if (mark is! Map || mark['type'] != 'link') continue;
    final attrs = mark['attrs'];
    if (attrs is Map && attrs['href'] is String) href = attrs['href'] as String;
  }
  return href;
}

/// The visible label of a diary mention; the id is the fallback.
String _diaryLinkLabel(Object? attrs) {
  if (attrs is! Map) return '';
  final label = attrs['label'];
  if (label is String && label.isNotEmpty) return label;
  final id = attrs['id'];
  return id is String ? id : '';
}

const Map<String, MediaKind> _mediaKinds = {
  'image': MediaKind.image,
  'video': MediaKind.video,
  'audio': MediaKind.audio,
  'attachment': MediaKind.attachment,
};

MediaKind? _mediaKindOf(Object? type) =>
    type is String ? _mediaKinds[type] : null;

String _mediaName(Object? attrs) {
  if (attrs is! Map) return '';
  final name = attrs['name'];
  return name is String ? MediaMarkup.sanitizeName(name) : '';
}

const Set<String> _textblocks = {'paragraph', 'heading', 'codeBlock'};

bool _hasTextChild(Object? content) =>
    content is List &&
    content.any((child) => child is Map && child['type'] == 'text');

String _plainInline(Object? nodes) {
  final buf = StringBuffer();
  if (nodes is! List) return '';
  for (final node in nodes) {
    if (node is! Map) continue;
    final text = node['text'];
    if (text is String) buf.write(text);
    buf.write(_plainInline(node['content']));
  }
  return buf.toString();
}

/// A diary as a Markdown resource: JSON front matter (which is valid YAML) then
/// the readable body. [linkStyle] follows [diaryToMarkdown].
String diaryMarkdownDocument(
  Diary diary, {
  String? categoryName,
  Map<String, dynamic> links = const {},
  DiaryLinkStyle linkStyle = DiaryLinkStyle.uri,
}) {
  final frontMatter = {
    'id': diary.id,
    'title': diary.title,
    'time': isoUtc(diary.time),
    'timeLocal': isoLocal(diary.time),
    'lastModified': isoUtc(diary.lastModified),
    'category': {'id': diary.categoryId, 'name': categoryName},
    'mood': diary.mood?.name,
    'tags': diary.tags,
    'show': diary.show,
    'uri': '$diaryUriPrefix${diary.id}',
    'links': links,
  };
  final body = truncate(diaryToMarkdown(diary, linkStyle: linkStyle));
  return '---\n'
      '${const JsonEncoder.withIndent('  ').convert(frontMatter)}\n'
      '---\n\n$body\n';
}

/// Category id to display name, for the summaries that carry a category.
Future<Map<String, String>> categoryNames(CategoryRepository categories) async {
  final all = await categories.getAllCategories();
  return {for (final category in all) category.id: category.categoryName};
}

/// One category as the catalog shows it.
///
/// [diaryCount] is the direct visible count; [diariesTotal] also counts the
/// descendants, which a tree view needs so a parent never looks emptier than
/// its children. A flat caller that omits it reports the direct count.
Map<String, dynamic> categoryInfo(
  Category category, {
  int? diaryCount,
  int? diariesTotal,
  List<Map<String, dynamic>> children = const [],
}) => {
  'id': category.id,
  'name': category.categoryName,
  'parentId': category.parentId,
  'color': category.color,
  'colorHex': colorHex(category.color),
  'lastModified': isoUtc(category.lastModified),
  'diaries': diaryCount,
  'diariesTotal': diariesTotal ?? diaryCount,
  'children': children,
};

/// Decodes a stored document so a JSON aware client sees structure instead of a
/// string inside a string; raw content that is not JSON is passed through.
Object? decodeJsonOrText(String content) {
  if (content.isEmpty) return content;
  try {
    return jsonDecode(content);
  } on FormatException {
    return content;
  }
}
