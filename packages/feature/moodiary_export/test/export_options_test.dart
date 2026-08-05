import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_export/moodiary_export.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

void main() {
  group('ExportSettings 持久化', () {
    test('往返不丢字段', () {
      const settings = ExportSettings(
        common: ExportCommon(
          includeTitle: false,
          includeMeta: false,
          media: ExportMediaPolicy.placeholder,
          merge: false,
          nameTemplate: '{title}',
        ),
        markdown: MarkdownExportOptions(
          dialect: MarkdownDialect.commonMark,
          frontMatter: false,
        ),
        docx: LayoutExportOptions(
          paper: ExportPaper.letter,
          margin: 720,
          fontSizePt: 14,
          lineSpacing: 2,
          firstLineIndent: false,
          eastAsiaFont: '思源宋体',
          asciiFont: 'Iowan',
        ),
        pdf: LayoutExportOptions(paper: ExportPaper.a5, eastAsiaFont: 'x.ttf'),
      );

      final restored = ExportSettings.decode(settings.encode());

      expect(restored.common.includeTitle, isFalse);
      expect(restored.common.media, ExportMediaPolicy.placeholder);
      expect(restored.common.merge, isFalse);
      expect(restored.common.nameTemplate, '{title}');
      expect(restored.markdown.dialect, MarkdownDialect.commonMark);
      expect(restored.markdown.frontMatter, isFalse);
      expect(restored.docx.paper, ExportPaper.letter);
      expect(restored.docx.margin, 720);
      expect(restored.docx.fontSizePt, 14);
      expect(restored.docx.lineSpacing, 2);
      expect(restored.docx.firstLineIndent, isFalse);
      expect(restored.docx.eastAsiaFont, '思源宋体');
      expect(restored.docx.asciiFont, 'Iowan');
      // 两种格式的排版配置互不覆盖。
      expect(restored.pdf.paper, ExportPaper.a5);
      expect(restored.pdf.eastAsiaFont, 'x.ttf');
    });

    test('存坏了退回默认而不是抛异常', () {
      // 设置页要能打开 —— 配置格式变过或写坏时不能把页面炸掉。
      expect(ExportSettings.decode('不是 json').common.merge, isTrue);
      expect(ExportSettings.decode('').docx.paper, ExportPaper.a4);
      expect(ExportSettings.decode('{"common": 42}').common.includeTitle, isTrue);
    });

    test('未知枚举值退回默认', () {
      const raw = '{"common":{"media":"someFutureMode"},'
          '"markdown":{"dialect":"someFutureDialect"},'
          '"docx":{"paper":"B5"}}';
      final settings = ExportSettings.decode(raw);
      expect(settings.common.media, ExportMediaPolicy.embed);
      expect(settings.markdown.dialect, MarkdownDialect.gfm);
      expect(settings.docx.paper, ExportPaper.a4);
    });
  });

  group('纸张单位换算', () {
    test('twip → mm（typst 按毫米取尺寸）', () {
      // A4 = 210 × 297 mm
      expect(ExportPaper.a4.widthMm, closeTo(210, 0.5));
      expect(ExportPaper.a4.heightMm, closeTo(297, 0.5));
      // Letter = 8.5 × 11 英寸
      expect(ExportPaper.letter.widthMm, closeTo(215.9, 0.5));
      expect(ExportPaper.letter.heightMm, closeTo(279.4, 0.5));
      expect(ExportPaper.a5.widthMm, closeTo(148, 0.5));
    });
  });

  group('ExportFormat', () {
    test('按 id 还原，未知 id 退回 markdown', () {
      expect(ExportFormat.byId('docx'), ExportFormat.docx);
      expect(ExportFormat.byId('pdf'), ExportFormat.pdf);
      expect(ExportFormat.byId('还没有的格式'), ExportFormat.markdown);
    });

    test('扩展名与格式对应', () {
      expect(ExportFormat.markdown.extension, 'md');
      expect(ExportFormat.docx.extension, 'docx');
      expect(ExportFormat.pdf.extension, 'pdf');
    });
  });
}
