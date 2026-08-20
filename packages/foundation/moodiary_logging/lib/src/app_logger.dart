import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();

  static final AppLogger _instance = ._();

  factory AppLogger() => _instance;

  /// release 下的落盘路径，由 app 组合根在启动时给出（[configure]）。
  ///
  /// 刻意不从 `AppFiles` 取：日志是最底层的东西，谁都可以用它，它不该反过来认识
  /// 文件布局。这一条就是本包能待在 foundation 而不必上浮到 core 的全部原因。
  static String? _logFilePath;

  /// 必须在第一次打日志之前调用，否则 release 下日志只进控制台（即没人看得见）。
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
