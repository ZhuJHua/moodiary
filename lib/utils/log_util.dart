import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:moodiary/utils/file_util.dart';

class FileOutput extends LogOutput {
  final bool overrideExisting;
  final Encoding encoding;
  IOSink? _sink;

  FileOutput({
    this.overrideExisting = false,
    this.encoding = utf8,
  });

  @override
  Future<void> init() async {
    final file = File(FileUtil.getErrorLogPath());
    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString('');
    }
    return super.init();
  }

  void _initIOSink() {
    _sink = File(FileUtil.getErrorLogPath()).openWrite(
      mode: overrideExisting ? FileMode.write : FileMode.append,
      encoding: encoding,
    );
  }

  @override
  void output(OutputEvent event) {
    if (_sink == null) _initIOSink();

    if (event.level.value >= Level.warning.value) {
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
  static final Logger _logger =
      Logger(output: kDebugMode ? null : FileOutput());

  static void printError(message,
      {required Object error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void printWTF(message,
      {required Object error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  static void printInfo(message) {
    if (kDebugMode) _logger.i(message);
  }
}
