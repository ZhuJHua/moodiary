import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();

  static final AppLogger _instance = ._();

  factory AppLogger() => _instance;

  static String? _logFilePath;

  /// 允许在首次打日志**之后**才配置：错误处理器装在启动最前面，configure 之前的
  /// 异常也会打到这里。logger 因此不能是 late final——那会让第一条早到的日志把
  /// 输出永久钉死在控制台，release 整场启动都不落盘；这里失效重建，下一条起生效。
  static void configure({required String logFilePath}) {
    _logFilePath = logFilePath;
    _instance._logger = null;
  }

  Logger? _logger;

  /// 可替换的 Logger 工厂（同 AppLockPin 的 seam 风格）：427aae3a 修过「configure
  /// 晚于首条日志时输出永久钉死在控制台」，没有这条缝那次回归无法被测试钉住。
  @visibleForTesting
  static Logger Function(String? logFilePath) loggerFactory = _defaultFactory;

  static Logger _defaultFactory(String? logFilePath) => Logger(
    output: kDebugMode || logFilePath == null
        ? ConsoleOutput()
        : FileOutput(file: File(logFilePath)),
    filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
  );

  /// 测试间复位：清掉已配置的路径与缓存的 Logger。
  @visibleForTesting
  static void debugReset() {
    _logFilePath = null;
    _instance._logger = null;
    loggerFactory = _defaultFactory;
  }

  Logger get _log => _logger ??= loggerFactory(_logFilePath);

  void e(Object message, {required Object error, StackTrace? stackTrace}) {
    _log.e(message, error: error, stackTrace: stackTrace);
  }

  void f(Object message, {required Object error, StackTrace? stackTrace}) {
    _log.f(message, error: error, stackTrace: stackTrace);
  }

  void i(Object message) {
    _log.i(message);
  }

  void d(Object message) {
    _log.d(message);
  }
}

final logger = AppLogger();
