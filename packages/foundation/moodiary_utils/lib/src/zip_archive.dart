import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// zip 读写失败（含 worker isolate 意外退出、归档里的越界路径）。
class ZipException implements Exception {
  const ZipException(this.message);

  final String message;

  @override
  String toString() => 'ZipException: $message';
}

/// zip 写入器：条目按调用顺序追加，字节条目 Deflate，文件条目 Stored 直存（媒体 / docx / pdf
/// 本身已是压缩格式，再压一遍只费时间）。CRC / 压缩 / 落盘全在专属 isolate 里跑，主 isolate
/// 只发命令，所以调用方可以在两次 add 之间照常查取消标记。
///
/// 中途失败一定要 [abort]：worker 攥着 fd，不关则半成品要等进程退出才真正释放磁盘——而失败
/// 原因往往正是磁盘满。[finish] 之后不必再 abort。
final class ZipWriter {
  ZipWriter._(this._port, this._commands, this._replies);

  /// 新建 [zipPath]（已存在则覆盖）。
  static Future<ZipWriter> create(String zipPath) async {
    final port = ReceivePort('ZipWriter');
    final replies = StreamIterator<Object?>(port);
    try {
      await Isolate.spawn(
        _worker,
        (port.sendPort, zipPath),
        onError: port.sendPort,
        onExit: port.sendPort,
        debugName: 'ZipWriter',
      );
      final ready = await _next(replies);
      if (ready is! SendPort) throw ZipException('unexpected reply: $ready');
      return ZipWriter._(port, ready, replies);
    } catch (_) {
      port.close();
      rethrow;
    }
  }

  final ReceivePort _port;
  final SendPort _commands;
  final StreamIterator<Object?> _replies;
  Future<void> _queue = Future.value();
  bool _closed = false;

  /// 以 Deflate 写入一段字节。
  Future<void> addBytes(String entryPath, Uint8List data) =>
      _run(_AddBytes(entryPath, TransferableTypedData.fromList([data])));

  /// 以 Stored 直存一个本地文件。
  Future<void> addFile(String entryPath, String filePath) =>
      _run(_AddFile(entryPath, filePath));

  /// 写中央目录并关闭；之后本实例不可再用。
  Future<void> finish() => _run(const _Finish(), last: true);

  /// 丢弃半成品并释放 fd（文件本身留给调用方删）。任何状态下都可以调，不抛。
  Future<void> abort() async {
    if (_closed) return;
    try {
      await _run(const _Abort(), last: true);
    } catch (_) {}
  }

  Future<void> _run(Object command, {bool last = false}) {
    final done = _queue.then((_) async {
      if (_closed) throw const ZipException('zip writer already closed');
      _commands.send(command);
      try {
        final reply = await _next(_replies);
        if (reply case (final String? error,)) {
          if (error != null) throw ZipException(error);
          return;
        }
        throw ZipException('unexpected reply: $reply');
      } finally {
        if (last) {
          _closed = true;
          _port.close();
        }
      }
    });
    // 一条失败不堵住后面的 abort。
    _queue = done.catchError((_) {});
    return done;
  }

  /// 下一条来自 worker 的消息。`null` 是 onExit、`List` 是 onError（未捕获的错误），
  /// 两者都意味着 worker 没了。
  static Future<Object?> _next(StreamIterator<Object?> replies) async {
    if (!await replies.moveNext()) {
      throw const ZipException('zip worker exited');
    }
    final message = replies.current;
    if (message == null) throw const ZipException('zip worker exited');
    if (message is List) throw ZipException('${message.first}');
    return message;
  }

  static Future<void> _worker((SendPort, String) init) async {
    final (replies, zipPath) = init;
    final OutputFileStream output;
    final ZipFileEncoder encoder;
    try {
      output = OutputFileStream(zipPath);
      encoder = ZipFileEncoder()..createWithStream(output, level: 6);
    } catch (e) {
      replies.send(['$e', '']);
      return;
    }
    final commands = ReceivePort('ZipWriter.commands');
    replies.send(commands.sendPort);
    await for (final command in commands) {
      String? error;
      var last = false;
      try {
        switch (command) {
          case _AddBytes(:final entryPath, :final data):
            encoder.addArchiveFile(
              ArchiveFile.bytes(entryPath, data.materialize().asUint8List()),
            );
          case _AddFile(:final entryPath, :final filePath):
            final file = File(filePath);
            final stream = InputFileStream(filePath);
            try {
              encoder.addArchiveFile(
                ArchiveFile.stream(entryPath, stream)
                  ..compression = .none
                  ..lastModTime =
                      file.lastModifiedSync().millisecondsSinceEpoch ~/ 1000,
              );
            } catch (_) {
              // 成功路径由 encoder 自己关流；失败时它可能没关到。
              stream.closeSync();
              rethrow;
            }
          case _Finish():
            encoder.closeSync();
            last = true;
          case _Abort():
            output.closeSync();
            last = true;
        }
      } catch (e) {
        error = '$e';
      }
      replies.send((error,));
      if (last) break;
    }
    commands.close();
  }
}

final class _AddBytes {
  const _AddBytes(this.entryPath, this.data);

  final String entryPath;
  final TransferableTypedData data;
}

final class _AddFile {
  const _AddFile(this.entryPath, this.filePath);

  final String entryPath;
  final String filePath;
}

final class _Finish {
  const _Finish();
}

final class _Abort {
  const _Abort();
}

/// 把 [zipPath] 全部解到 [destDir]（不存在则创建）。整个过程在一个 isolate 里跑。
///
/// 条目路径逃出 [destDir] 的归档（`../`、绝对路径）与符号链接条目一律拒绝——我们自己
/// 写的包里没有这些。写盘错误原样抛出，不像 `extractArchiveToDisk` 那样吞掉。
Future<void> extractZip({required String zipPath, required String destDir}) =>
    Isolate.run(() => _extract(zipPath, destDir), debugName: 'extractZip');

void _extract(String zipPath, String destDir) {
  final root = p.normalize(p.absolute(destDir));
  Directory(root).createSync(recursive: true);
  final input = InputFileStream(zipPath);
  try {
    final decoder = ZipDecoder();
    final archive = decoder.decodeStream(input);
    // 找不到中央目录结尾时 ZipDecoder 静默给空包，不当归档。
    if (decoder.directory.filePosition < 0) {
      throw ZipException('not a zip archive: $zipPath');
    }
    for (final entry in archive) {
      final target = p.normalize(p.join(root, entry.name));
      if (!p.isWithin(root, target)) {
        throw ZipException('unsafe entry path in archive: ${entry.name}');
      }
      if (entry.isSymbolicLink) {
        throw ZipException('symlink entry refused: ${entry.name}');
      }
      if (entry.isDirectory) {
        Directory(target).createSync(recursive: true);
        continue;
      }
      Directory(p.dirname(target)).createSync(recursive: true);
      final output = OutputFileStream(target);
      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }
    }
  } finally {
    input.closeSync();
  }
}
