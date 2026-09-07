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
