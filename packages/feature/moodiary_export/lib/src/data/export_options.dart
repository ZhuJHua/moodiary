import 'dart:convert';

import 'markdown_writer.dart';

enum ExportFormat {
  markdown('markdown', 'md'),
  docx('docx', 'docx'),
  pdf('pdf', 'pdf');

  final String id;
  final String extension;

  const ExportFormat(this.id, this.extension);

  static ExportFormat byId(String id) =>
      ExportFormat.values.firstWhere((f) => f.id == id, orElse: () => markdown);
}

/// 音视频在 docx / pdf 里没有对等物，这里决定怎么降级。
enum ExportMediaPolicy {
  /// 图片内嵌；音视频写占位（视频带封面）。
  embed,

  /// 图片也只写占位文字，产物最小。
  placeholder,

  /// 完全不含媒体。
  none,
}

/// 纸张。twip = 1/1440 英寸。
enum ExportPaper {
  a4('A4', 11906, 16838),
  letter('Letter', 12240, 15840),
  a5('A5', 8391, 11906);

  final String label;
  final int width;
  final int height;

  const ExportPaper(this.label, this.width, this.height);

  /// typst 按毫米取尺寸；1 twip = 1/1440 英寸。
  double get widthMm => width * 25.4 / 1440;

  double get heightMm => height * 25.4 / 1440;

  static ExportPaper byLabel(String label) =>
      ExportPaper.values.firstWhere((p) => p.label == label, orElse: () => a4);
}

/// 三种格式共用的部分。
class ExportCommon {
  final bool includeTitle;

  /// 标题下写一行「日期 · 天气 · 位置 · 分类」。
  final bool includeMeta;
  final ExportMediaPolicy media;

  /// 合并成一个文件；关闭则每篇一份并打包 zip。
  final bool merge;

  /// 每篇一份时的文件名模板，支持 `{date}` `{title}` `{id}`。
  final String nameTemplate;

  const ExportCommon({
    this.includeTitle = true,
    this.includeMeta = true,
    this.media = .embed,
    this.merge = true,
    this.nameTemplate = '{date}-{title}',
  });

  ExportCommon copyWith({
    bool? includeTitle,
    bool? includeMeta,
    ExportMediaPolicy? media,
    bool? merge,
    String? nameTemplate,
  }) => ExportCommon(
    includeTitle: includeTitle ?? this.includeTitle,
    includeMeta: includeMeta ?? this.includeMeta,
    media: media ?? this.media,
    merge: merge ?? this.merge,
    nameTemplate: nameTemplate ?? this.nameTemplate,
  );

  Map<String, dynamic> toJson() => {
    'includeTitle': includeTitle,
    'includeMeta': includeMeta,
    'media': media.name,
    'merge': merge,
    'nameTemplate': nameTemplate,
  };

  factory ExportCommon.fromJson(Map<String, dynamic> json) => ExportCommon(
    includeTitle: json['includeTitle'] as bool? ?? true,
    includeMeta: json['includeMeta'] as bool? ?? true,
    media: ExportMediaPolicy.values.firstWhere(
      (m) => m.name == json['media'],
      orElse: () => ExportMediaPolicy.embed,
    ),
    merge: json['merge'] as bool? ?? true,
    nameTemplate: json['nameTemplate'] as String? ?? '{date}-{title}',
  );
}

/// Markdown 专属。方言与 front matter 直接透传给 [MarkdownWriter]。
class MarkdownExportOptions {
  final MarkdownDialect dialect;
  final bool frontMatter;

  const MarkdownExportOptions({this.dialect = .gfm, this.frontMatter = true});

  MarkdownExportOptions copyWith({
    MarkdownDialect? dialect,
    bool? frontMatter,
  }) => MarkdownExportOptions(
    dialect: dialect ?? this.dialect,
    frontMatter: frontMatter ?? this.frontMatter,
  );

  Map<String, dynamic> toJson() => {
    'dialect': dialect.name,
    'frontMatter': frontMatter,
  };

  factory MarkdownExportOptions.fromJson(Map<String, dynamic> json) =>
      MarkdownExportOptions(
        dialect: MarkdownDialect.values.firstWhere(
          (d) => d.name == json['dialect'],
          orElse: () => MarkdownDialect.gfm,
        ),
        frontMatter: json['frontMatter'] as bool? ?? true,
      );
}

/// 排版类格式（docx / pdf）共用的页面与字体设定。
class LayoutExportOptions {
  final ExportPaper paper;

  /// 四边页边距（twip）。
  final int margin;
  final double fontSizePt;
  final double lineSpacing;
  final bool firstLineIndent;

  /// DOCX 写进 `w:rFonts` 的字体名（只存名不嵌文件，随便填）；
  /// PDF 下这里存的是用户已导入字体的文件名，必须真实存在且为 TrueType。
  final String eastAsiaFont;
  final String asciiFont;

  const LayoutExportOptions({
    this.paper = .a4,
    this.margin = 1440,
    this.fontSizePt = 11,
    this.lineSpacing = 1.5,
    this.firstLineIndent = true,
    this.eastAsiaFont = '',
    this.asciiFont = 'Georgia',
  });

  LayoutExportOptions copyWith({
    ExportPaper? paper,
    int? margin,
    double? fontSizePt,
    double? lineSpacing,
    bool? firstLineIndent,
    String? eastAsiaFont,
    String? asciiFont,
  }) => LayoutExportOptions(
    paper: paper ?? this.paper,
    margin: margin ?? this.margin,
    fontSizePt: fontSizePt ?? this.fontSizePt,
    lineSpacing: lineSpacing ?? this.lineSpacing,
    firstLineIndent: firstLineIndent ?? this.firstLineIndent,
    eastAsiaFont: eastAsiaFont ?? this.eastAsiaFont,
    asciiFont: asciiFont ?? this.asciiFont,
  );

  Map<String, dynamic> toJson() => {
    'paper': paper.label,
    'margin': margin,
    'fontSizePt': fontSizePt,
    'lineSpacing': lineSpacing,
    'firstLineIndent': firstLineIndent,
    'eastAsiaFont': eastAsiaFont,
    'asciiFont': asciiFont,
  };

  factory LayoutExportOptions.fromJson(Map<String, dynamic> json) =>
      LayoutExportOptions(
        paper: .byLabel(json['paper'] as String? ?? 'A4'),
        margin: json['margin'] as int? ?? 1440,
        fontSizePt: (json['fontSizePt'] as num?)?.toDouble() ?? 11,
        lineSpacing: (json['lineSpacing'] as num?)?.toDouble() ?? 1.5,
        firstLineIndent: json['firstLineIndent'] as bool? ?? true,
        eastAsiaFont: json['eastAsiaFont'] as String? ?? '',
        asciiFont: json['asciiFont'] as String? ?? 'Georgia',
      );
}

/// 一次导出的完整配置。按格式分别持久化，互不覆盖。
class ExportSettings {
  final ExportCommon common;
  final MarkdownExportOptions markdown;
  final LayoutExportOptions docx;
  final LayoutExportOptions pdf;

  const ExportSettings({
    this.common = const ExportCommon(),
    this.markdown = const MarkdownExportOptions(),
    this.docx = const LayoutExportOptions(eastAsiaFont: '宋体'),
    this.pdf = const LayoutExportOptions(),
  });

  ExportSettings copyWith({
    ExportCommon? common,
    MarkdownExportOptions? markdown,
    LayoutExportOptions? docx,
    LayoutExportOptions? pdf,
  }) => ExportSettings(
    common: common ?? this.common,
    markdown: markdown ?? this.markdown,
    docx: docx ?? this.docx,
    pdf: pdf ?? this.pdf,
  );

  String encode() => jsonEncode({
    'common': common.toJson(),
    'markdown': markdown.toJson(),
    'docx': docx.toJson(),
    'pdf': pdf.toJson(),
  });

  static ExportSettings decode(String raw) {
    if (raw.isEmpty) return const ExportSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ExportSettings(
        common: .fromJson(json['common'] as Map<String, dynamic>? ?? const {}),
        markdown: .fromJson(
          json['markdown'] as Map<String, dynamic>? ?? const {},
        ),
        docx: .fromJson(json['docx'] as Map<String, dynamic>? ?? const {}),
        pdf: .fromJson(json['pdf'] as Map<String, dynamic>? ?? const {}),
      );
    } catch (_) {
      // 配置格式变过 / 存坏了：退回默认，不让设置页打不开。
      return const ExportSettings();
    }
  }
}
