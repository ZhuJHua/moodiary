import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_export/moodiary_export.dart';

void main() {
  group('ExportSettings 持久化', () {
    test('往返不丢字段', () {
      const settings = ExportSettings(
        common: ExportCommon(
          includeTitle: false,
          includeMeta: false,
          media: .placeholder,
          merge: false,
          nameTemplate: '{title}',
        ),
        docx: LayoutExportOptions(
          paper: .letter,
          margin: 720,
          fontSizePt: 14,
          lineSpacing: 2,
          firstLineIndent: false,
          eastAsiaFont: '思源宋体',
          asciiFont: 'Iowan',
        ),
        pdf: LayoutExportOptions(paper: .a5, eastAsiaFont: 'x.ttf'),
        image: ImageExportOptions(
          brightness: Brightness.dark,
          widthDp: 480,
          scale: 2,
          watermark: false,
        ),
      );

      final restored = ExportSettings.decode(settings.encode());

      expect(restored.common.includeTitle, isFalse);
      expect(restored.common.media, ExportMediaPolicy.placeholder);
      expect(restored.common.merge, isFalse);
      expect(restored.common.nameTemplate, '{title}');
      expect(restored.image.brightness, Brightness.dark);
      expect(restored.image.widthDp, 480);
      expect(restored.image.scale, 2);
      expect(restored.image.watermark, isFalse);
      expect(restored.docx.paper, ExportPaper.letter);
      expect(restored.docx.margin, 720);
      expect(restored.docx.fontSizePt, 14);
      expect(restored.docx.lineSpacing, 2);
      expect(restored.docx.firstLineIndent, isFalse);
      expect(restored.docx.eastAsiaFont, '思源宋体');
      expect(restored.docx.asciiFont, 'Iowan');
      expect(restored.pdf.paper, ExportPaper.a5);
      expect(restored.pdf.eastAsiaFont, 'x.ttf');
    });

    test('存坏了退回默认而不是抛异常', () {
      expect(ExportSettings.decode('不是 json').common.merge, isTrue);
      expect(ExportSettings.decode('').docx.paper, ExportPaper.a4);
      expect(
        ExportSettings.decode('{"common": 42}').common.includeTitle,
        isTrue,
      );
    });

    test('未知枚举值退回默认', () {
      const raw =
          '{"common":{"media":"someFutureMode"},'
          '"docx":{"paper":"B5"}}';
      final settings = ExportSettings.decode(raw);
      expect(settings.common.media, ExportMediaPolicy.embed);
      expect(settings.docx.paper, ExportPaper.a4);
    });
  });

  group('纸张单位换算', () {
    test('twip → mm（typst 按毫米取尺寸）', () {
      expect(ExportPaper.a4.widthMm, closeTo(210, 0.5));
      expect(ExportPaper.a4.heightMm, closeTo(297, 0.5));
      expect(ExportPaper.letter.widthMm, closeTo(215.9, 0.5));
      expect(ExportPaper.letter.heightMm, closeTo(279.4, 0.5));
      expect(ExportPaper.a5.widthMm, closeTo(148, 0.5));
    });
  });

  group('ExportFormat', () {
    test('按 id 还原，未知 id 退回 markdown', () {
      expect(ExportFormat.byId('docx'), ExportFormat.docx);
      expect(ExportFormat.byId('pdf'), ExportFormat.pdf);
      expect(ExportFormat.byId('image'), ExportFormat.image);
      expect(ExportFormat.byId('还没有的格式'), ExportFormat.markdown);
    });

    test('扩展名与格式对应', () {
      expect(ExportFormat.markdown.extension, 'md');
      expect(ExportFormat.docx.extension, 'docx');
      expect(ExportFormat.pdf.extension, 'pdf');
      expect(ExportFormat.image.extension, 'png');
    });
  });

  group('位置开关', () {
    test('默认关 —— 导出的文件是要发给别人的', () {
      expect(const ExportCommon().includePosition, isFalse);
    });

    test('往返保住 true', () {
      const settings = ExportSettings(
        common: ExportCommon(includePosition: true),
      );
      expect(
        ExportSettings.decode(settings.encode()).common.includePosition,
        isTrue,
      );
    });

    test('老配置里没有这个键时按关处理', () {
      final decoded = ExportSettings.decode('{"common":{"merge":false}}');
      expect(decoded.common.includePosition, isFalse);
      expect(decoded.common.merge, isFalse);
    });
  });

  group('长图分带', () {
    test('首尾相接、不重不漏', () {
      final bands = imageBands(4500, 2000);
      expect(bands.length, 3);
      expect(bands[0], (0.0, 2000.0));
      expect(bands[1], (2000.0, 2000.0));
      expect(bands[2], (4000.0, 500.0));
      expect(bands.fold<double>(0, (sum, b) => sum + b.$2), 4500);
      for (var i = 1; i < bands.length; i++) {
        expect(bands[i].$1, bands[i - 1].$1 + bands[i - 1].$2);
      }
    });

    test('切点都是整数：乘倍率不会出现半个像素', () {
      for (final total in [1, 7, 1999, 2000, 2001, 12345]) {
        for (final band in imageBands(total, 2000)) {
          expect(band.$1 % 1, 0);
          expect(band.$2 % 1, 0);
        }
      }
    });

    test('内容不足一带只出一带；空内容也出 1px，而不是非法的 0 高 PNG', () {
      expect(imageBands(800, 2000), [(0.0, 800.0)]);
      expect(imageBands(0, 2000), [(0.0, 1.0)]);
    });

    test('恰好整除时不多出一条空带', () {
      final bands = imageBands(6000, 2000);
      expect(bands.length, 3);
      expect(bands.last, (4000.0, 2000.0));
    });
  });
}
