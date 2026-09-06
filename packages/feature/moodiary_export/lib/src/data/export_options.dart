import 'dart:convert';
import 'dart:ui' show Brightness;

enum ExportFormat {
  markdown('markdown', 'md'),
  docx('docx', 'docx'),
  pdf('pdf', 'pdf'),
  image('image', 'png');

  final String id;
  final String extension;

  const ExportFormat(this.id, this.extension);

  static ExportFormat byId(String id) =>
      ExportFormat.values.firstWhere((f) => f.id == id, orElse: () => markdown);
}

enum ExportMediaPolicy {
  embed,

  placeholder,

  none,
}

enum ExportPaper {
  a4('A4', 11906, 16838),
  letter('Letter', 12240, 15840),
  a5('A5', 8391, 11906);

  final String label;
  final int width;
  final int height;

  const ExportPaper(this.label, this.width, this.height);

  // 1 twip = 1/1440 英寸
  double get widthMm => width * 25.4 / 1440;

  double get heightMm => height * 25.4 / 1440;

  static ExportPaper byLabel(String label) =>
      ExportPaper.values.firstWhere((p) => p.label == label, orElse: () => a4);
}

class ExportCommon {
  final bool includeTitle;

  final bool includeMeta;
  final ExportMediaPolicy media;

  final bool merge;

  final String nameTemplate;

  final bool includePosition;

  const ExportCommon({
    this.includeTitle = true,
    this.includeMeta = true,
    this.media = .embed,
    this.merge = true,
    this.nameTemplate = '{date}-{title}',
    this.includePosition = false,
  });

  ExportCommon copyWith({
    bool? includeTitle,
    bool? includeMeta,
    ExportMediaPolicy? media,
    bool? merge,
    String? nameTemplate,
    bool? includePosition,
  }) => ExportCommon(
    includeTitle: includeTitle ?? this.includeTitle,
    includeMeta: includeMeta ?? this.includeMeta,
    media: media ?? this.media,
    merge: merge ?? this.merge,
    nameTemplate: nameTemplate ?? this.nameTemplate,
    includePosition: includePosition ?? this.includePosition,
  );

  Map<String, dynamic> toJson() => {
    'includeTitle': includeTitle,
    'includeMeta': includeMeta,
    'media': media.name,
    'merge': merge,
    'nameTemplate': nameTemplate,
    'includePosition': includePosition,
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
    includePosition: json['includePosition'] as bool? ?? false,
  );
}

class LayoutExportOptions {
  final ExportPaper paper;

  final int margin;
  final double fontSizePt;
  final double lineSpacing;
  final bool firstLineIndent;

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

class ImageExportOptions {
  final Brightness? brightness;

  final double widthDp;

  final int scale;

  final bool watermark;

  const ImageExportOptions({
    this.brightness,
    this.widthDp = 360,
    this.scale = 3,
    this.watermark = true,
  });

  ImageExportOptions copyWith({
    Brightness? brightness,
    bool clearBrightness = false,
    double? widthDp,
    int? scale,
    bool? watermark,
  }) => ImageExportOptions(
    brightness: clearBrightness ? null : (brightness ?? this.brightness),
    widthDp: widthDp ?? this.widthDp,
    scale: scale ?? this.scale,
    watermark: watermark ?? this.watermark,
  );

  Map<String, dynamic> toJson() => {
    'brightness': brightness?.name ?? 'system',
    'widthDp': widthDp,
    'scale': scale,
    'watermark': watermark,
  };

  factory ImageExportOptions.fromJson(Map<String, dynamic> json) =>
      ImageExportOptions(
        brightness: switch (json['brightness'] as String?) {
          'light' => Brightness.light,
          'dark' => Brightness.dark,
          _ => null,
        },
        widthDp: (json['widthDp'] as num?)?.toDouble() ?? 360,
        scale: (json['scale'] as num?)?.toInt() ?? 3,
        watermark: json['watermark'] as bool? ?? true,
      );
}

class ExportSettings {
  final ExportCommon common;
  final LayoutExportOptions docx;
  final LayoutExportOptions pdf;
  final ImageExportOptions image;

  const ExportSettings({
    this.common = const ExportCommon(),
    this.docx = const LayoutExportOptions(eastAsiaFont: '宋体'),
    this.pdf = const LayoutExportOptions(),
    this.image = const ImageExportOptions(),
  });

  ExportSettings copyWith({
    ExportCommon? common,
    LayoutExportOptions? docx,
    LayoutExportOptions? pdf,
    ImageExportOptions? image,
  }) => ExportSettings(
    common: common ?? this.common,
    docx: docx ?? this.docx,
    pdf: pdf ?? this.pdf,
    image: image ?? this.image,
  );

  String encode() => jsonEncode({
    'common': common.toJson(),
    'docx': docx.toJson(),
    'pdf': pdf.toJson(),
    'image': image.toJson(),
  });

  static ExportSettings decode(String raw) {
    if (raw.isEmpty) return const ExportSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ExportSettings(
        common: .fromJson(json['common'] as Map<String, dynamic>? ?? const {}),
        docx: .fromJson(json['docx'] as Map<String, dynamic>? ?? const {}),
        pdf: .fromJson(json['pdf'] as Map<String, dynamic>? ?? const {}),
        image: .fromJson(json['image'] as Map<String, dynamic>? ?? const {}),
      );
    } catch (_) {
      return const ExportSettings();
    }
  }
}
