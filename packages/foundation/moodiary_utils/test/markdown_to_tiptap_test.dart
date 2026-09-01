import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

Map<String, dynamic> _parse(String? json) =>
    jsonDecode(json!) as Map<String, dynamic>;

/// 深度收集指定 type 的节点。
List<Map<String, dynamic>> _find(dynamic node, String type) {
  final out = <Map<String, dynamic>>[];
  void walk(dynamic n) {
    if (n is! Map) return;
    if (n['type'] == type) out.add(n.cast<String, dynamic>());
    final content = n['content'];
    if (content is List) content.forEach(walk);
  }

  walk(node);
  return out;
}

String _allText(dynamic node) {
  final buf = StringBuffer();
  void walk(dynamic n) {
    if (n is! Map) return;
    if (n['text'] is String) buf.write(n['text']);
    final content = n['content'];
    if (content is List) content.forEach(walk);
  }

  walk(node);
  return buf.toString();
}

void main() {
  group('MarkdownToTiptap — HTML 实体不外泄', () {
    test('正文里的 " & < > 原样保留，不转义成实体', () {
      final doc = _parse(MarkdownToTiptap.convert('He said "hi" & 1 < 2'));
      expect(_allText(doc), 'He said "hi" & 1 < 2');
    });

    test('行内代码与代码块同样不转义', () {
      final inline = _parse(MarkdownToTiptap.convert('前缀 `a<b` 后缀'));
      expect(_allText(inline), contains('a<b'));

      final block = _parse(
        MarkdownToTiptap.convert('```\nif (a < b && c) {}\n```'),
      );
      expect(_allText(block), 'if (a < b && c) {}');
    });
  });

  group('MarkdownToTiptap — 列表项 schema（paragraph block*）', () {
    test('列表项首子是图片时补空段落，媒体节点保留', () {
      final doc = _parse(
        MarkdownToTiptap.convert('- 早餐\n- ![](image-x.png)\n- 晚餐'),
      );
      for (final item in _find(doc, 'listItem')) {
        final content = item['content'] as List;
        expect((content.first as Map)['type'], 'paragraph');
      }
      final images = _find(doc, 'image');
      expect(images, hasLength(1));
      expect(images.single['attrs']['src'], 'image-x.png');
    });

    test('任务项首子是图片时同样补段落', () {
      final doc = _parse(MarkdownToTiptap.convert('- [ ] ![](image-y.png)'));
      final item = _find(doc, 'taskItem').single;
      expect(((item['content'] as List).first as Map)['type'], 'paragraph');
      expect(_find(doc, 'image').single['attrs']['src'], 'image-y.png');
    });
  });

  group('MarkdownToTiptap — 媒体分流', () {
    test('image-/audio-/video- 前缀还原为一等节点', () {
      final doc = _parse(
        MarkdownToTiptap.convert(
          '![](image-a.png)\n\n![](audio-b.m4a)\n\n![](video-c.mp4)',
        ),
      );
      expect(_find(doc, 'image').single['attrs']['src'], 'image-a.png');
      expect(_find(doc, 'audio').single['attrs']['filename'], 'audio-b.m4a');
      expect(_find(doc, 'video').single['attrs']['filename'], 'video-c.mp4');
    });
  });
}
