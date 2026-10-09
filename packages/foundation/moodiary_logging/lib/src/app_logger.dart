import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();

  static final AppLogger _instance = ._();

  factory AppLogger() => _instance;

  static String? _logFilePath;

  static void configure({required String logFilePath}) {
    _logFilePath = logFilePath;
    _instance._logger = null;
  }

  Logger? _logger;

  @visibleForTesting
  static Logger Function(String? logFilePath) loggerFactory = _defaultFactory;

  static Logger _defaultFactory(String? logFilePath) => Logger(
    output: kDebugMode || logFilePath == null
        ? ConsoleOutput()
        : FileOutput(file: File(logFilePath)),
    filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
  );

  @visibleForTesting
  static void debugReset() {
    _logFilePath = null;
    _instance._logger = null;
    loggerFactory = _defaultFactory;
  }

  Logger get _log => _logger ??= loggerFactory(_logFilePath);

  // SqliteException.toString() 会带上绑定参数，也就是日记正文；落盘前截掉
  @visibleForTesting
  static Object redact(Object error, {bool debug = kDebugMode}) {
    if (debug) return error;
    final text = error.toString();
    final cut = text.indexOf('Causing statement');
    return cut < 0 ? error : text.substring(0, cut).trimRight();
  }

  void e(Object message, {required Object error, StackTrace? stackTrace}) {
    _log.e(message, error: redact(error), stackTrace: stackTrace);
  }

  void f(Object message, {required Object error, StackTrace? stackTrace}) {
    _log.f(message, error: redact(error), stackTrace: stackTrace);
  }

  void i(Object message) {
    _log.i(message);
  }

  void d(Object message) {
    _log.d(message);
  }
}

final logger = AppLogger();
