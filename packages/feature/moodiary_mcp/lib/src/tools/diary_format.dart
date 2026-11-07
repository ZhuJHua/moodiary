/// Formatting shared by the diary tools and resources: time rendering, list
/// summaries and a Tiptap document to Markdown walker.
///
/// Nothing here invents content: media only appears when the document itself
/// carries a media node, and a legacy (non Tiptap) diary is handed back as the
/// text it already is.
library;

import 'dart:convert';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

/// Upper bound for one tool or resource payload. A model pays for every
/// character, and one huge diary must not flood a context window.
const int mcpResultChars = 100000;

/// Length of the `excerpt` field of a diary summary.
const int mcpExcerptChars = 200;

/// URI prefix of the single diary resource template.
const String diaryUriPrefix = 'moodiary://diary/';

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

/// One line preview of the diary body, used by every list shaped result.
String excerptOf(Diary diary, {int chars = mcpExcerptChars}) {
  final text = MediaMarkup.forModel(diary.contentText)
      .replaceAll(RegExp(r'\s+'), ' ');
  return truncate(text.trim(), chars);
}

/// `#AARRGGBB`, or `null` when the category has no colour.
String? colorHex(int? argb) => argb == null
    ? null
    : '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// The list shaped projection a client sees for one diary.
Map<String, dynamic> diarySummary(Diary diary, {String? categoryName}) => {
  'id': diary.id,
  'title': diary.title,
  'time': isoUtc(diary.time),
  'timeLocal': isoLocal(diary.time),
  'lastModified': isoUtc(diary.lastModified),
  'categoryId': diary.categoryId,
  'categoryName': categoryName,
  'mood': diary.mood?.name,
  'tags': diary.tags,
  'excerpt': excerptOf(diary),
  'show': diary.show,
};

/// The tiptap body of [diary] as Markdown. Legacy diaries are not converted:
/// a Markdown diary already holds Markdown, a rich text one only has its text.
String diaryToMarkdown(Diary diary) =>
    switch (DiaryType.fromValue(diary.type)) {
      DiaryType.tiptap => tiptapToMarkdown(diary.content),
      DiaryType.markdown => diary.content,
      DiaryType.richText => MediaMarkup.forModel(diary.contentText),
    };

/// Renders a stored Tiptap document as Markdown.
///
/// Handles the node types the app's editor writes: paragraphs, headings, bullet
/// and ordered lists, block quotes, code blocks, horizontal rules, links,
/// diary mentions and media. Unknown blocks are descended into so no text is
/// lost; media is rendered from the node that is actually in the document.
String tiptapToMarkdown(String content) {
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
  _blocks(decoded['content'], out);
  return out.toString().trim();
}

void _blocks(Object? nodes, StringBuffer out) {
  if (nodes is! List) return;
  for (final node in nodes) {
    if (node is! Map) continue;
    final block = _block(node);
    if (block == null || block.isEmpty) continue;
    if (out.isNotEmpty) out.write('\n\n');
    out.write(block);
  }
}

String? _block(Map<dynamic, dynamic> node) {
  final attrs = node['attrs'];
  switch (node['type']) {
    case 'paragraph':
      final text = _inline(node['content']);
      return text.trim().isEmpty ? null : text;
    case 'heading':
      final raw = attrs is Map ? attrs['level'] : null;
      final level = raw is int ? raw.clamp(1, 6) : 1;
      final text = _inline(node['content']).trim();
      return text.isEmpty ? null : '${'#' * level} $text';
    case 'codeBlock':
      final language = attrs is Map && attrs['language'] is String
          ? attrs['language'] as String
          : '';
      return '```$language\n${_plainInline(node['content'])}\n```';
    case 'blockquote':
      final inner = StringBuffer();
      _blocks(node['content'], inner);
      final text = inner.toString().trim();
      if (text.isEmpty) return null;
      return [
        for (final line in text.split('\n')) line.isEmpty ? '>' : '> $line',
      ].join('\n');
    case 'bulletList':
      return _list(node['content'], ordered: false);
    case 'orderedList':
      final start = attrs is Map && attrs['start'] is int
          ? attrs['start'] as int
          : 1;
      return _list(node['content'], ordered: true, start: start);
    case 'horizontalRule':
      return '---';
    case 'image' || 'video' || 'audio' || 'attachment':
      return _media(node['type'], attrs);
    default:
      final inner = StringBuffer();
      _blocks(node['content'], inner);
      return inner.isEmpty ? null : inner.toString();
  }
}

String? _list(Object? items, {required bool ordered, int start = 1}) {
  if (items is! List) return null;
  final lines = <String>[];
  var number = start;
  for (final item in items) {
    if (item is! Map || item['type'] != 'listItem') continue;
    final inner = StringBuffer();
    _blocks(item['content'], inner);
    final text = inner.toString().trim();
    if (text.isEmpty) continue;
    final marker = ordered ? '${number++}.' : '-';
    final body = text.split('\n');
    final depth = item['attrs'] is Map ? item['attrs']['depth'] : null;
    final indent = depth is int && depth > 0 ? '  ' * depth : '';
    lines.add('$indent$marker ${body.first}');
    for (final line in body.skip(1)) {
      lines.add(line.isEmpty ? '' : '$indent  $line');
    }
  }
  return lines.isEmpty ? null : lines.join('\n');
}

String? _media(Object? type, Object? attrs) {
  if (attrs is! Map) return null;
  final src = attrs['src'];
  if (src is! String || src.isEmpty) return null;
  final name = attrs['name'];
  final label = name is String && name.isNotEmpty ? name : src;
  return switch (type) {
    'image' => '![$label]($src)',
    'attachment' => '[$label]($src)',
    _ => '[$type: $label]($src)',
  };
}

String _inline(Object? nodes) {
  final buf = StringBuffer();
  if (nodes is! List) return '';
  for (final node in nodes) {
    if (node is! Map) continue;
    switch (node['type']) {
      case 'text':
        buf.write(_marked(node));
      case 'hardBreak':
        buf.write('  \n');
      case 'diaryLink':
        buf.write(_diaryLink(node['attrs']));
      case 'image' || 'video' || 'audio' || 'attachment':
        buf.write(_media(node['type'], node['attrs']) ?? '');
      default:
        buf.write(_inline(node['content']));
    }
  }
  return buf.toString();
}

String _diaryLink(Object? attrs) {
  final id = attrs is Map ? attrs['id'] : null;
  final label = attrs is Map ? attrs['label'] : null;
  final text = label is String && label.isNotEmpty ? label : '$id';
  if (id is! String || id.isEmpty) return text;
  return '[$text]($diaryUriPrefix$id)';
}

String _marked(Map<dynamic, dynamic> node) {
  final raw = node['text'];
  if (raw is! String || raw.isEmpty) return '';
  final marks = node['marks'];
  if (marks is! List) return raw;
  var bold = false;
  var italic = false;
  var code = false;
  var strike = false;
  var highlight = false;
  var underline = false;
  String? href;
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
  var text = raw;
  if (code) text = '`$text`';
  if (bold) text = '**$text**';
  if (italic) text = '*$text*';
  if (strike) text = '~~$text~~';
  if (highlight) text = '==$text==';
  if (underline) text = '<u>$text</u>';
  if (href != null && href.isNotEmpty) text = '[$text]($href)';
  return text;
}

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
/// the readable body.
String diaryMarkdownDocument(
  Diary diary, {
  String? categoryName,
  Map<String, dynamic> links = const {},
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
  final body = truncate(diaryToMarkdown(diary));
  return '---\n'
      '${const JsonEncoder.withIndent('  ').convert(frontMatter)}\n'
      '---\n\n$body\n';
}

/// Category id to display name, for the summaries that carry a category.
Future<Map<String, String>> categoryNames(CategoryRepository categories) async {
  final all = await categories.getAllCategories();
  return {for (final category in all) category.id: category.categoryName};
}
