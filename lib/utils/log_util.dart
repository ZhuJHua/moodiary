import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/notice_util.dart';

class LogUtil {
  static final Logger _logger = Logger(
    output: kDebugMode
        ? ConsoleOutput()
        : FileOutput(file: File(FileUtil.getErrorLogPath())),
    filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
  );

  static void printError(message,
      {required Object error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    NoticeUtil.showBug(message: '$message\n${error.toString()}');
  }

  static void printWTF(message,
      {required Object error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
    NoticeUtil.showBug(message: '$message\n${error.toString()}');
  }

  static void printInfo(message) {
    if (kDebugMode) _logger.i(message);
  }
}
