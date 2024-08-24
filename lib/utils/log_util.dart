import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

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
  }

  void printWTF(message, {required Object error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      logger.f(message, error: error, stackTrace: stackTrace);
    }
  }

  void printInfo(message) {
    if (kDebugMode) {
      logger.i(message);
    }
  }
}
