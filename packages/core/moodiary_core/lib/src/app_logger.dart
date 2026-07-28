import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:moodiary_core/src/files/app_files.dart';

class AppLogger {
  AppLogger._();

  static final AppLogger _instance = AppLogger._();

  factory AppLogger() => _instance;
  late final Logger _logger = Logger(
    output: kDebugMode
        ? ConsoleOutput()
        : FileOutput(file: File(AppFiles.getErrorLogPath())),
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
