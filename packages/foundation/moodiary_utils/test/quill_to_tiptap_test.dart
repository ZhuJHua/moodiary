import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

List<dynamic> convert(List<Map<String, dynamic>> ops) {
  final json = QuillDeltaToTiptap.convert(jsonEncode(ops));
  expect(json, isNotNull);
  return (jsonDecode(json!) as Map<String, dynamic>)['content'] as List;
}

Map<String, dynamic> codeLine(String text) => {
  'insert': '$text\n',
  'attributes': {'code-block': true},
};

void main() {
  group('QuillDeltaToTiptap code-block 行内 embed', () {
    test('纯文本代码块不受影响', () {
      final blocks = convert([
        {'insert': 'a'},
        codeLine(''),
        {'insert': 'b'},
        codeLine(''),
      ]);
      expect(blocks, [
        {
          'type': 'codeBlock',
          'content': [
            {'type': 'text', 'text': 'a\nb'},
          ],
        },
      ]);
    });

    test('代码块中的空行保留', () {
      final blocks = convert([
        {'insert': 'a'},
        codeLine(''),
        codeLine(''),
        {'insert': 'b'},
        codeLine(''),
      ]);
      expect((blocks.single as Map)['content'], [
        {'type': 'text', 'text': 'a\n\nb'},
      ]);
    });

    test('代码行内图片切断代码块并保留为 image 节点', () {
      final blocks = convert([
        {'insert': 'before'},
        codeLine(''),
        {
          'insert': {'image': 'image-1.webp'},
        },
        codeLine(''),
        {'insert': 'after'},
        codeLine(''),
      ]);
      expect(blocks, [
        {
          'type': 'codeBlock',
          'content': [
            {'type': 'text', 'text': 'before'},
          ],
        },
        {
          'type': 'image',
          'attrs': {'src': 'image-1.webp'},
        },
        {
          'type': 'codeBlock',
          'content': [
            {'type': 'text', 'text': 'after'},
          ],
        },
      ]);
    });

    test('同一代码行文本与音频共存：文本入代码块、音频成节点', () {
      final blocks = convert([
        {'insert': 'code'},
        {
          'insert': {'audio': 'audio-1.m4a'},
        },
        codeLine(''),
      ]);
      expect(blocks, [
        {
          'type': 'codeBlock',
          'content': [
            {'type': 'text', 'text': 'code'},
          ],
        },
        {
          'type': 'audio',
          'attrs': {'filename': 'audio-1.m4a'},
        },
      ]);
    });

    test('代码块以 embed 开头不产生空代码块', () {
      final blocks = convert([
        {
          'insert': {'video': 'video-1.mp4'},
        },
        codeLine(''),
        {'insert': 'tail'},
        codeLine(''),
      ]);
      expect(blocks, [
        {
          'type': 'video',
          'attrs': {'filename': 'video-1.mp4'},
        },
        {
          'type': 'codeBlock',
          'content': [
            {'type': 'text', 'text': 'tail'},
          ],
        },
      ]);
    });

    test('一行多个 embed 全部保留', () {
      final blocks = convert([
        {
          'insert': {'image': 'image-1.webp'},
        },
        {
          'insert': {'image': 'image-2.webp'},
        },
        codeLine(''),
      ]);
      expect(blocks, [
        {
          'type': 'image',
          'attrs': {'src': 'image-1.webp'},
        },
        {
          'type': 'image',
          'attrs': {'src': 'image-2.webp'},
        },
      ]);
    });
  });

  group('QuillDeltaToTiptap 常规路径回归', () {
    test('普通段落内嵌图片拆分为 paragraph/image/paragraph', () {
      final blocks = convert([
        {'insert': 'a'},
        {
          'insert': {'image': 'image-1.webp'},
        },
        {'insert': 'b\n'},
      ]);
      expect(blocks, [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': 'a'},
          ],
        },
        {
          'type': 'image',
          'attrs': {'src': 'image-1.webp'},
        },
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': 'b'},
          ],
        },
      ]);
    });

    test('非法 JSON 与非数组返回 null', () {
      expect(QuillDeltaToTiptap.convert('not json'), isNull);
      expect(QuillDeltaToTiptap.convert('{"a":1}'), isNull);
    });
  });
}
