import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

void main() {
  test('removeLineBreaks replaces breaks with one space', () {
    expect('hello\r\n  world\n'.removeLineBreaks(), 'hello world ');
  });
}
