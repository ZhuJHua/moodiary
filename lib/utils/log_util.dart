import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:mood_diary/utils/file_util.dart';

class FileOutput extends LogOutput {
  final bool overrideExisting;
  final Encoding encoding;
  IOSink? _sink;
  File? file;

  FileOutput({
    this.overrideExisting = false,
    this.encoding = utf8,
  });

  /// 初始化文件输出流
  Future<void> _initializeSink() async {
    if (_sink == null) {
      file = File(FileUtil.getErrorLogPath());
      _sink = file!.openWrite(
        mode: overrideExisting ? FileMode.write : FileMode.append,
        encoding: encoding,
      );
    }
  }

  @override
  void output(OutputEvent event) async {
    await _initializeSink();
    if (_sink != null && event.level.index >= Level.info.index) {
      _sink?.writeAll(event.lines, '\n');
    }
  }

  @override
  Future<void> destroy() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    return super.destroy();
  }
}

class LogUtil {
  static final Logger _logger = Logger(output: kDebugMode ? null : FileOutput());

  static void printError(message, {required Object error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void printWTF(message, {required Object error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  static void printInfo(message) {
    if (kDebugMode) _logger.i(message);
  }
}
