import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:injectable/injectable.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:path/path.dart' as p;

@singleton
class SyncLogger {
  SyncLogger._();

  static const int _bufferLimit = 500;

  static const int _retentionDays = 7;

  static const String _dirName = 'sync_logs';
  static const String _filePrefix = 'sync-';
  static const String _fileSuffix = '.jsonl';

  final List<SyncEvent> _buffer = [];
  final StreamController<SyncEvent> _controller =
      StreamController<SyncEvent>.broadcast();

  Directory? _dir;
  IOSink? _sink;
  String? _currentDayKey;

  List<SyncEvent> get recent => .unmodifiable(_buffer);

  Stream<SyncEvent> get events => _controller.stream;

  @FactoryMethod(preResolve: true)
  static Future<SyncLogger> create() async {
    final logger = SyncLogger._();
    await logger._init();
    return logger;
  }

  Future<void> _init() async {
    try {
      final supportPath = PlatformService.get().applicationSupportPath;
      _dir = Directory(p.join(supportPath, _dirName));
      await _dir!.create(recursive: true);
      await _cleanupOldFiles();
    } catch (e, s) {
      logger.e('SyncLogger 落盘不可用，降级为纯内存模式', error: e, stackTrace: s);
    }
  }

  void log(SyncEvent event) {
    _buffer.add(event);
    if (_buffer.length > _bufferLimit) {
      _buffer.removeRange(0, _buffer.length - _bufferLimit);
    }
    if (!_controller.isClosed) {
      _controller.add(event);
    }
    unawaited(_persist(event));
  }

  void info(
    SyncEventKind kind, {
    SyncEventReason? reason,
    Map<String, Object?>? payload,
  }) => log(.now(level: .info, kind: kind, reason: reason, payload: payload));

  void warn(
    SyncEventKind kind, {
    SyncEventReason? reason,
    Map<String, Object?>? payload,
  }) => log(.now(level: .warn, kind: kind, reason: reason, payload: payload));

  void error(
    SyncEventKind kind, {
    SyncEventReason? reason,
    Map<String, Object?>? payload,
  }) => log(.now(level: .error, kind: kind, reason: reason, payload: payload));

  Future<void> _persist(SyncEvent event) async {
    if (_dir == null) return;
    try {
      await _ensureSink(event.at);
      _sink?.writeln(jsonEncode(event.toJson()));
    } catch (_) {
    }
  }

  Future<void> _ensureSink(DateTime at) async {
    final key = _dayKey(at);
    if (_sink != null && _currentDayKey == key) return;
    await _sink?.flush();
    await _sink?.close();
    final path = p.join(_dir!.path, '$_filePrefix$key$_fileSuffix');
    _sink = File(path).openWrite(mode: .append, encoding: utf8);
    _currentDayKey = key;
  }

  String _dayKey(DateTime t) {
    final local = t.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _cleanupOldFiles() async {
    if (_dir == null) return;
    final cutoff = DateTime.now().subtract(
      const Duration(days: _retentionDays),
    );
    final cutoffKey = _dayKey(cutoff);
    await for (final entity in _dir!.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(_filePrefix) || !name.endsWith(_fileSuffix)) {
        continue;
      }
      final key = name.substring(
        _filePrefix.length,
        name.length - _fileSuffix.length,
      );
      // 字典序比较 YYYY-MM-DD 字符串等价于日期比较
      if (key.compareTo(cutoffKey) < 0) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<List<SyncEvent>> readDay([DateTime? day]) async {
    if (_dir == null) return const [];
    final key = _dayKey(day ?? .now());
    final path = p.join(_dir!.path, '$_filePrefix$key$_fileSuffix');
    if (!await File(path).exists()) return const [];
    return Isolate.run(() => parseDayFile(path));
  }

  @visibleForTesting
  static List<SyncEvent> parseDayFile(String path) {
    final events = <SyncEvent>[];
    for (final line in File(path).readAsLinesSync(encoding: utf8)) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, Object?>;
        events.add(.fromJson(json));
      } catch (_) {}
    }
    return events;
  }

  Future<List<DateTime>> availableDays() async {
    if (_dir == null) return const [];
    final keys = <String>[];
    await for (final entity in _dir!.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(_filePrefix) || !name.endsWith(_fileSuffix)) {
        continue;
      }
      keys.add(
        name.substring(_filePrefix.length, name.length - _fileSuffix.length),
      );
    }
    keys.sort((a, b) => b.compareTo(a));
    return [
      for (final key in keys)
        if (DateTime.tryParse(key) case final DateTime day) day,
    ];
  }

  Future<void> clearAll() async {
    _buffer.clear();
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _currentDayKey = null;
    if (_dir == null) return;
    await for (final entity in _dir!.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (!name.startsWith(_filePrefix) || !name.endsWith(_fileSuffix)) {
          continue;
        }
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
