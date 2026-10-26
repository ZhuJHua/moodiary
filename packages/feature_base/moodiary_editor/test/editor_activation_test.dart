import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_editor/src/moodiary_editor.dart';

void main() {
  test('激活按顺序下发，每条语句独立捕获并报告错误', () {
    final source = buildEditorActivationJs(
      content: '',
      title: '',
      editable: false,
      theme: const {'dark': true},
      metaJson: '{"category":"日常"}',
      linksJson: '{"outgoing":[]}',
    );
    final statements = source.split('\n');
    expect(statements, hasLength(6));
    final methods = [
      'setContent',
      'setTitle',
      'setEditable',
      'setTheme',
      'setMeta',
      'setLinks',
    ];
    for (var i = 0; i < methods.length; i++) {
      expect(
        statements[i],
        startsWith('try{window.MoodiaryBridge.${methods[i]}('),
      );
      expect(statements[i], endsWith(');}catch(e){console.error(e);}'));
    }
  });

  test('字体就绪后的重发不覆盖正文和标题', () {
    final source = buildEditorActivationJs(editable: true, theme: const {});
    expect(source.split('\n'), hasLength(4));
    expect(source, isNot(contains('setContent')));
    expect(source, isNot(contains('setTitle')));
    expect(
      RegExp(r'MoodiaryBridge\.(\w+)').allMatches(source).map((m) => m[1]),
      ['setEditable', 'setTheme', 'setMeta', 'setLinks'],
    );
    expect(source, contains('setMeta("")'));
    expect(source, contains('setLinks("")'));
  });

  test('正文与标题通过 JSON 编码，保留引号、换行与脚本形状的文本', () {
    const content =
        '{"text":"引号 \\" 与路径 C:\\\\diary"}\n'
        "');throw new Error('content'); //\u2028\u2029";
    const title = '标题 "quoted"\n第二行\\';
    final source = buildEditorActivationJs(
      content: content,
      title: title,
      editable: true,
      theme: const {},
    );
    for (final (method, value) in [
      ('setContent', content),
      ('setTitle', title),
    ]) {
      final prefix = 'window.MoodiaryBridge.$method(';
      final start = source.indexOf(prefix) + prefix.length;
      final end = source.indexOf(');}catch(e)', start);
      final argument = source.substring(start, end);
      expect(argument, jsonEncode(value));
      expect(jsonDecode(argument), value);
    }
  });
}
