import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'file_util.dart';

class LogUtil {
  static final Logger _logger =
      kDebugMode ? Logger() : Logger(printer: null, output: FileOutput(file: FileUtil.getErrorLogFile()));

  static void printError(message, {required Object error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void printWTF(message, {required Object error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  static void printInfo(message) {
    if (kDebugMode) _logger.i(message);
  }

// static void appendLogFile(String errorType, {required Object error, StackTrace? stackTrace}) {
//   // 生成错误日志
//   final logMessage = '''$errorType
//   ${DateTime.now().toIso8601String()}
//   Error: ${error.toString()}
//   StackTrace: ${stackTrace?.toString()}
//   ''';
//   FileUtil.errorLog(logMessage);
// }
}
