import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/data/model/sync_event.dart';
import 'package:path/path.dart' as p;

/// 同步引擎事件日志接收器：① 广播流（[events]）；② 内存 ring buffer（UI 进入
/// Dashboard 即见最近事件）；③ 按天 jsonl 文件，超 [_retentionDays] 天自动清理。
/// 单例，启动时由 DI 预解析（[create] 是 preResolve 工厂）。
@singleton
class SyncLogger {
  SyncLogger._();

  factory SyncLogger.get() => getIt<SyncLogger>();

  /// 内存 ring buffer 上限，超过丢弃最旧一批。
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

  /// 内存中本进程已产生的事件（最旧在前）。
  List<SyncEvent> get recent => .unmodifiable(_buffer);

  /// 广播流，每个监听者从订阅之后的事件开始收。
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
      // 目录创建失败 → 降级为纯内存模式，sink 留 null 不再写盘。
      // 降级行为保留（测试依赖它在无 PlatformService 的宿主上安全通过），
      // 但违约至少要有声音——否则「同步日志整场没落盘」无从察觉。
      logger.e('SyncLogger 落盘不可用，降级为纯内存模式', error: e, stackTrace: s);
    }
  }

  /// 先入 buffer、再广播、最后异步落盘（互不阻塞）。
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

  /// [reason] 是同一 [SyncEventKind] 下的细分语义（可选）；[payload] 携带机器可读
  /// 细节。两者都会随事件持久化，文案渲染在日志页完成。
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
      // 写日志失败不能影响同步流程，吞掉。
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

  /// 读取指定日期（默认今天）的历史日志，解析失败的行静默跳过。
  Future<List<SyncEvent>> readDay([DateTime? day]) async {
    if (_dir == null) return const [];
    final key = _dayKey(day ?? .now());
    final file = File(p.join(_dir!.path, '$_filePrefix$key$_fileSuffix'));
    if (!await file.exists()) return const [];
    final lines = await file.readAsLines(encoding: utf8);
    final events = <SyncEvent>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, Object?>;
        events.add(.fromJson(json));
      } catch (_) {}
    }
    return events;
  }

  /// 列出磁盘上仍保留的日志日期（新 → 旧），供日志页筛选。
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
    keys.sort((a, b) => b.compareTo(a)); // 字典序倒排 = 日期新→旧
    return [
      for (final key in keys)
        if (DateTime.tryParse(key) case final DateTime day) day,
    ];
  }

  /// 清空内存 buffer 和所有日志文件。UI 的"清空日志"按钮调用。
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

  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
