import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/js_sandbox.dart';

/// 真跑 quickjs-ng：flutter test 会为宿主编译 flutter_js 的 code asset。
void main() {
  test('最后一个表达式的值就是结果，不必 return', () async {
    final out = await JsSandbox.run(
      'const a = [1, 2, 3]; a.reduce((x, y) => x + y, 0) / a.length',
    );
    expect(out.value, '2');
    expect(out.logs, isEmpty);
    expect(out.truncated, isFalse);
  });

  test('对象走 JSON，字符串不带引号，undefined 为空', () async {
    expect(
      (await JsSandbox.run('({a: 1, b: [2, 3]})')).value,
      '{"a":1,"b":[2,3]}',
    );
    expect((await JsSandbox.run('"hi"')).value, 'hi');
    expect((await JsSandbox.run('let x = 1;')).value, '');
  });

  test('console 分级收集，不外发', () async {
    final out = await JsSandbox.run(
      'console.log("a", {b: 1}); console.warn("w"); console.error("e"); 42',
    );
    expect(out.value, '42');
    expect(out.logs, ['[LOG] a {"b":1}', '[WARN] w', '[ERROR] e']);
  });

  test('宿主桥全部拆掉', () async {
    final out = await JsSandbox.run(
      '[typeof sendMessage, typeof setTimeout, typeof fetch, typeof require]',
    );
    expect(out.value, '["undefined","undefined","undefined","undefined"]');
  });

  test('每次都是新沙箱', () async {
    await JsSandbox.run('globalThis.leak = 1');
    expect((await JsSandbox.run('typeof leak')).value, 'undefined');
  });

  test('抛错原样回报，并带上已打出的日志', () async {
    await expectLater(
      JsSandbox.run('console.log("before"); null.x'),
      throwsA(
        isA<JsSandboxException>().having(
          (e) => e.message,
          'message',
          allOf(contains('TypeError'), contains('[LOG] before')),
        ),
      ),
    );
  });

  test('语法错误进 SyntaxError', () async {
    await expectLater(
      JsSandbox.run('const = ;'),
      throwsA(
        isA<JsSandboxException>().having(
          (e) => e.message,
          'message',
          contains('SyntaxError'),
        ),
      ),
    );
  });

  test('死循环被截止时间杀掉', () async {
    final sw = Stopwatch()..start();
    await expectLater(
      JsSandbox.run('while (true) {}'),
      throwsA(isA<JsSandboxException>()),
    );
    expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
  });

  test('输出超限被截断并标记', () async {
    final out = await JsSandbox.run(
      '"x".repeat(${JsSandbox.maxOutputChars * 2})',
    );
    expect(out.value.length, JsSandbox.maxOutputChars);
    expect(out.truncated, isTrue);
  });
}
