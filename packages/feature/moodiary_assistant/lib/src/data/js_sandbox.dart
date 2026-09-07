import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_js/flutter_js.dart';

class JsOutcome {
  const JsOutcome({
    required this.value,
    required this.logs,
    required this.truncated,
  });

  final String value;

  final List<String> logs;

  final bool truncated;
}

class JsSandboxException implements Exception {
  const JsSandboxException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class JsSandbox {
  static const int memoryLimitBytes = 32 * 1024 * 1024;
  static const int stackSizeBytes = 512 * 1024;
  static const int timeoutMs = 2000;

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
      // 序幕里的间接 eval 返回脚本最后一个表达式的值
      final result = runtime.evaluate(
        '__moodiary.run(${jsonEncode(code)})',
        name: '<eval>',
      );
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
