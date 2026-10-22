import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

void main() {
  group('StringExt.preview', () {
    test('keeps line breaks between paragraphs', () {
      expect('一二三四五六七八\n一二三四五六七八'.preview(), '一二三四五六七八\n一二三四五六七八');
    });

    test('collapses blank lines and trims', () {
      expect('\n  a  \n\n\n b\n\n'.preview(), 'a\n b');
    });

    test('single line joins with spaces', () {
      expect('hello\n\nworld'.preview(singleLine: true), 'hello world');
    });

    test('truncates by runes', () {
      expect('😀😀😀'.preview(maxRunes: 2), '😀😀');
    });
  });

  test('removeLineBreaks replaces breaks with one space', () {
    expect('hello\r\n  world\n'.removeLineBreaks(), 'hello world ');
  });
}
