import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

void main() {
  group('QuillDelta.plainText', () {
    test('拼接字符串 insert，跳过 embed', () {
      final delta = jsonEncode([
        {'insert': 'hello '},
        {
          'insert': {'image': 'image-1.png'},
        },
        {'insert': 'world\n'},
      ]);
      expect(QuillDelta.plainText(delta), 'hello world\n');
    });

    test('保留行内属性文本，属性本身不产出字符', () {
      final delta = jsonEncode([
        {
          'insert': '粗体',
          'attributes': {'bold': true},
        },
        {'insert': '普通\n'},
      ]);
      expect(QuillDelta.plainText(delta), '粗体普通\n');
    });

    test('非法 JSON / 顶层非数组返回 null，由调用方回退原文', () {
      expect(QuillDelta.plainText('不是 JSON'), isNull);
      expect(QuillDelta.plainText('{"insert":"x"}'), isNull);
    });

    test('空 Delta 得空串', () {
      expect(QuillDelta.plainText('[]'), '');
    });
  });

  group('QuillDelta.isDelta', () {
    test('合法 Delta 数组为真，其余为假', () {
      expect(QuillDelta.isDelta('[{"insert":"a\\n"}]'), isTrue);
      expect(QuillDelta.isDelta('[]'), isTrue);
      expect(QuillDelta.isDelta('裸文本'), isFalse);
      expect(QuillDelta.isDelta('{"ops":[]}'), isFalse);
      // 恰好是 JSON 数组的裸文本：没有任何带 insert 的 Map op，不算 Delta。
      expect(QuillDelta.isDelta('["买菜","做饭"]'), isFalse);
      expect(QuillDelta.isDelta('[2026]'), isFalse);
      expect(QuillDelta.isDelta('[{"a":1}]'), isFalse);
    });
  });

  group('QuillDelta.wrapPlainText', () {
    test('裸文本包成最小合法 Delta 并补尾换行', () {
      final wrapped = QuillDelta.wrapPlainText('今天很好');
      expect(jsonDecode(wrapped), [
        {'insert': '今天很好\n'},
      ]);
      expect(QuillDelta.isDelta(wrapped), isTrue);
      expect(QuillDelta.plainText(wrapped), '今天很好\n');
    });

    test('已有尾换行不重复补', () {
      expect(jsonDecode(QuillDelta.wrapPlainText('a\n')), [
        {'insert': 'a\n'},
      ]);
    });

    test('空串产出仅含换行的 Delta（对齐旧 Document() 的行为）', () {
      expect(jsonDecode(QuillDelta.wrapPlainText('')), [
        {'insert': '\n'},
      ]);
    });
  });
}
