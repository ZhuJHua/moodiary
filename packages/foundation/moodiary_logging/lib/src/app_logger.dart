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
  }

  late final Logger _logger = Logger(
    output: kDebugMode || _logFilePath == null
        ? ConsoleOutput()
        : FileOutput(file: File(_logFilePath!)),
    filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
  );

  void e(Object message, {required Object error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  void f(Object message, {required Object error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  void i(Object message) {
    _logger.i(message);
  }

  void d(Object message) {
    _logger.d(message);
  }
}

final logger = AppLogger();
