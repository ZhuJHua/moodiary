/// 导出中间表示（IR）。
///
/// 三种导出格式（markdown / docx / pdf）不各写一份 tiptap 遍历器：Dart 侧只遍历一次
/// [ExportDoc]，三个 writer 都消费它。这样「节点清单 + 降级策略」（音视频怎么占位、双链
/// 怎么表示、taskItem 怎么打勾）只有一处定义。
///
/// 更要紧的是 Rust 侧的 docx 生成只认这套 IR、不认 tiptap schema —— tiptap 升级会动
/// schema，IR 是我们自己的契约，不跟着上游走。故本文件的 JSON 形状即 FFI 契约，
/// 改字段要同步 rust/src/api/docx.rs 的镜像结构。
library;

/// 行内片段。一段连续的、样式相同的文本。
class ExportSpan {
  final String text;
  final bool bold;
  final bool italic;
  final bool strike;
  final bool underline;
  final bool code;

  /// link mark 的 href。
  final String? href;

  /// diaryLink（双链）指向的日记 id；非空时 [text] 是链接标签。
  final String? diaryLinkId;

  const ExportSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.underline = false,
    this.code = false,
    this.href,
    this.diaryLinkId,
  });

  bool get isPlain =>
      !bold &&
      !italic &&
      !strike &&
      !underline &&
      !code &&
      href == null &&
      diaryLinkId == null;

  Map<String, dynamic> toJson() => {
    'text': text,
    if (bold) 'bold': true,
    if (italic) 'italic': true,
    if (strike) 'strike': true,
    if (underline) 'underline': true,
    if (code) 'code': true,
    if (href != null) 'href': href,
    if (diaryLinkId != null) 'diaryLinkId': diaryLinkId,
  };
}

sealed class ExportBlock {
  const ExportBlock();

  Map<String, dynamic> toJson();
}

class ParagraphBlock extends ExportBlock {
  final List<ExportSpan> spans;

  const ParagraphBlock(this.spans);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'paragraph',
    'spans': [for (final s in spans) s.toJson()],
  };
}

class HeadingBlock extends ExportBlock {
  /// 1-6。
  final int level;
  final List<ExportSpan> spans;

  const HeadingBlock(this.level, this.spans);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'heading',
    'level': level,
    'spans': [for (final s in spans) s.toJson()],
  };
}

/// 列表项。[checked] 非空表示这是任务项（taskItem）。
class ExportListItem {
  final List<ExportBlock> children;
  final bool? checked;

  const ExportListItem(this.children, {this.checked});

  Map<String, dynamic> toJson() => {
    'children': [for (final b in children) b.toJson()],
    if (checked != null) 'checked': checked,
  };
}

class ListBlock extends ExportBlock {
  final bool ordered;

  /// orderedList 的起始序号（attrs.start，默认 1）。
  final int start;
  final List<ExportListItem> items;

  const ListBlock({
    required this.ordered,
    required this.items,
    this.start = 1,
  });

  /// 任一项带勾选状态即视为任务列表 —— markdown 写 `- [x]`，docx/pdf 写 ☑/☐。
  bool get isTask => items.any((i) => i.checked != null);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'list',
    'ordered': ordered,
    'start': start,
    'items': [for (final i in items) i.toJson()],
  };
}

class QuoteBlock extends ExportBlock {
  final List<ExportBlock> children;

  const QuoteBlock(this.children);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'quote',
    'children': [for (final b in children) b.toJson()],
  };
}

class CodeBlock extends ExportBlock {
  /// lowlight 的自由字符串语言标签，可能为空或是目标端不认识的名字。
  final String? language;
  final String text;

  const CodeBlock(this.text, {this.language});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'code',
    if (language != null && language!.isNotEmpty) 'language': language,
    'text': text,
  };
}

class DividerBlock extends ExportBlock {
  const DividerBlock();

  @override
  Map<String, dynamic> toJson() => const {'type': 'divider'};
}

class ImageBlock extends ExportBlock {
  /// 本地图片的绝对路径；[isExternal] 为 true 时这里是原始外链 URL。
  final String path;
  final String? alt;

  /// 正文列宽百分比上限（25/50/75/100），null = 不限。
  final int? widthPercent;

  /// 粘贴进来的外链图（src 不是 `image-` 前缀），导出时不下载、只当链接处理。
  final bool isExternal;

  const ImageBlock({
    required this.path,
    this.alt,
    this.widthPercent,
    this.isExternal = false,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'image',
    'path': path,
    if (alt != null && alt!.isNotEmpty) 'alt': alt,
    if (widthPercent != null) 'widthPercent': widthPercent,
    if (isExternal) 'external': true,
  };
}

enum ExportMediaKind { audio, video }

/// 音视频占位。docx/pdf 都放不进可播放媒体，统一降级为「图标/封面 + 文件名」。
class MediaBlock extends ExportBlock {
  final ExportMediaKind kind;
  final String filename;

  /// 视频封面的绝对路径（文件可能不存在，写入方需自行判存在性）。
  final String? coverPath;

  /// 媒体文件的绝对路径，供「随附文件一起导出」用。
  final String path;

  const MediaBlock({
    required this.kind,
    required this.filename,
    required this.path,
    this.coverPath,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'media',
    'kind': kind.name,
    'filename': filename,
    'path': path,
    if (coverPath != null) 'coverPath': coverPath,
  };
}

class ExportCell {
  final List<ExportBlock> children;
  final int colspan;
  final int rowspan;
  final String? align;
  final bool header;

  const ExportCell(
    this.children, {
    this.colspan = 1,
    this.rowspan = 1,
    this.align,
    this.header = false,
  });

  Map<String, dynamic> toJson() => {
    'children': [for (final b in children) b.toJson()],
    if (colspan != 1) 'colspan': colspan,
    if (rowspan != 1) 'rowspan': rowspan,
    if (align != null) 'align': align,
    if (header) 'header': true,
  };
}

class TableBlock extends ExportBlock {
  final List<List<ExportCell>> rows;

  const TableBlock(this.rows);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'table',
    'rows': [
      for (final r in rows) [for (final c in r) c.toJson()],
    ],
  };
}

/// 一篇日记的导出形态：元数据 + 正文块。
///
/// [time] 已是本地时刻（模型里存的是绝对时刻 UTC，转换在 [TiptapToExportDoc] 之前完成）。
class ExportDoc {
  final String id;
  final String title;
  final DateTime time;
  final double mood;
  final List<String> weather;
  final List<String> position;
  final List<String> tags;
  final String? categoryName;
  final List<ExportBlock> blocks;

  /// 遍历时遇到的、IR 表达不了的 tiptap 节点类型（去重）。非空说明编辑器加了新节点
  /// 而这里没跟上 —— UI 应当把它报给用户，而不是静默产出缺内容的文件。
  final Set<String> unsupportedNodes;

  const ExportDoc({
    required this.id,
    required this.title,
    required this.time,
    required this.blocks,
    this.mood = 0.5,
    this.weather = const [],
    this.position = const [],
    this.tags = const [],
    this.categoryName,
    this.unsupportedNodes = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'time': time.toIso8601String(),
    'mood': mood,
    'weather': weather,
    'position': position,
    'tags': tags,
    if (categoryName != null) 'categoryName': categoryName,
    'blocks': [for (final b in blocks) b.toJson()],
  };
}
