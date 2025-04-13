import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:moodiary/utils/file_util.dart';

class LogUtil {
  LogUtil._();

  static final LogUtil _instance = LogUtil._();

  factory LogUtil() => _instance;
  late final Logger _logger = Logger(
    output:
        kDebugMode
            ? ConsoleOutput()
            : FileOutput(file: File(FileUtil.getErrorLogPath())),
    filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
  );

  void e(message, {required Object error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  void f(message, {required Object error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  void i(message) {
    if (kDebugMode) _logger.i(message);
  }

  void d(message) {
    if (kDebugMode) _logger.d(message);
  }
}

final logger = LogUtil();
