import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_js/flutter_js.dart';

/// 一次求值的结果。
class JsOutcome {
  const JsOutcome({
    required this.value,
    required this.logs,
    required this.truncated,
  });

  /// 最后一个表达式的值。对象走 `JSON.stringify`，`undefined` 为空串。
  final String value;

  /// `console.log` / `info` / `warn` / `error` 收集到的行，带级别前缀。
  final List<String> logs;

  /// 结果或日志被截断过。
  final bool truncated;
}

/// 脚本抛出的错误（含语法错误、超时、内存上限），文本是 JS 侧的原始报错。
class JsSandboxException implements Exception {
  const JsSandboxException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 受限的 JavaScript 求值：给助手当「跑一段脚本」的工具用。
///
/// 读者是模型，模型写的代码不可信 —— 不是恶意，而是**跑飞是常态**：一个 `while(true)`
/// 或者一次巨大分配就是日常。所以三道闸门（内存 / 栈 / 截止时间）在唯一入口里一次装齐。
///
/// 沙箱里**什么都没有**：flutter_js 自带的 `sendMessage` 桥、`setTimeout`、打到宿主的
/// `console` 都在序幕里拆掉，没有 fetch、定时器、文件系统、模块加载。模型只能算它自己
/// 写进代码里的值。要让它读日记，那是另一个决定，不在这一层。
///
/// 每次调用新建一个 runtime，跑完即弃，整段在一个临时 isolate 里：求值是同步阻塞的，
/// 两秒的超时不能压在 UI 线程上。
abstract final class JsSandbox {
  static const int memoryLimitBytes = 32 * 1024 * 1024;
  static const int stackSizeBytes = 512 * 1024;
  static const int timeoutMs = 2000;

  /// 结果与日志各自的上限。**不是节俭，是止损**：工具结果要回灌进模型上下文并计费，
  /// 而 `while(true) console.log(x)` 在超时触发之前能产出好几 MB。
  static const int maxOutputChars = 4000;

  static Future<JsOutcome> run(String code) =>
      Isolate.run(() => _run(code), debugName: 'JsSandbox');

  static JsOutcome _run(String code) {
    final runtime = QuickJsRuntime2(
      stackSize: stackSizeBytes,
      timeout: timeoutMs,
      memoryLimit: memoryLimitBytes,
      hostPromiseRejectionHandler: (_) {},
    );
    try {
      _check(runtime.evaluate(_prelude, name: '<prelude>'));
      // 用 JSON 字面量把脚本原样递进去，序幕里的间接 eval 给出最后一个表达式的值。
      final result = runtime.evaluate(
        '__moodiary.run(${jsonEncode(code)})',
        name: '<eval>',
      );
      // 出错也把已经打出来的日志带上：模型据此定位是哪一步跑飞的。
      final logs = _readLogs(runtime);
      if (result.isError) {
        final (message, _) = _clamp(result.stringResult);
        throw JsSandboxException(
          logs.isEmpty ? message : '$message\nConsole:\n${logs.join('\n')}',
        );
      }
      final (value, valueCut) = _clamp(result.stringResult);
      final (joined, logsCut) = _clamp(logs.join('\n'));
      return JsOutcome(
        value: value,
        logs: joined.isEmpty ? const [] : joined.split('\n'),
        truncated: valueCut || logsCut,
      );
    } finally {
      runtime.dispose();
    }
  }

  static List<String> _readLogs(QuickJsRuntime2 runtime) {
    final result = runtime.evaluate('__moodiary.logs()', name: '<logs>');
    if (result.isError) return const [];
    final decoded = jsonDecode(result.stringResult);
    return decoded is List ? decoded.cast<String>() : const [];
  }

  static void _check(JsEvalResult result) {
    if (result.isError) throw JsSandboxException(result.stringResult);
  }

  static (String, bool) _clamp(String s) => s.length <= maxOutputChars
      ? (s, false)
      : (s.substring(0, maxOutputChars), true);

  /// 拆掉 flutter_js 装进来的宿主桥，换上只收集不外发的 console。
  ///
  /// `sendMessage` 是 `initChannelFunctions` 用 `this[key] = val` 挂上去的（可 delete），
  /// `setTimeout` 是函数声明（不可 delete 但可写），`console` 是 `var`（可写）。
  static const String _prelude = r'''
(() => {
  const g = globalThis;
  const logs = [];
  const fmt = (v) => {
    if (typeof v === 'string') return v;
    try {
      const s = JSON.stringify(v);
      return s === undefined ? String(v) : s;
    } catch (_) {
      return String(v);
    }
  };
  const sink = (tag) => (...args) => {
    logs.push('[' + tag + '] ' + args.map(fmt).join(' '));
  };
  g.console = {
    log: sink('LOG'),
    info: sink('INFO'),
    warn: sink('WARN'),
    error: sink('ERROR'),
  };
  delete g.sendMessage;
  g.setTimeout = undefined;
  g.__NATIVE_FLUTTER_JS__setTimeoutCallbacks = undefined;
  Object.defineProperty(g, '__moodiary', {
    value: {
      logs: () => JSON.stringify(logs),
      run: (src) => {
        const v = (0, eval)(src);
        return v === undefined ? '' : fmt(v);
      },
    },
  });
})();
''';
}
