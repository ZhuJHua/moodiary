import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:mood_diary/utils/utils.dart';

class LogUtil {
  late Logger logger;

  LogUtil() {
    if (kDebugMode) {
      logger = Logger();
    }
  }

  void printError(message, {required Object error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      logger.e(message, error: error, stackTrace: stackTrace);
    }
    appendLogFile(message, error: error, stackTrace: stackTrace);
  }

  void printWTF(message, {required Object error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      logger.f(message, error: error, stackTrace: stackTrace);
    }
    appendLogFile(message, error: error, stackTrace: stackTrace);
  }

  void printInfo(message) {
    if (kDebugMode) {
      logger.i(message);
    }
  }

  void appendLogFile(String errorType, {required Object error, StackTrace? stackTrace}) {
    // 生成错误日志
    final logMessage = '''$errorType
    ${DateTime.now().toIso8601String()}
    Error: ${error.toString()}
    StackTrace: ${stackTrace?.toString()}
    ''';
    Utils().fileUtil.errorLog(logMessage);
  }
}
