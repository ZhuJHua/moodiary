import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

/// Serializes writes and keeps one rollback file without retaining an open sink.
class RotatingFileOutput extends LogOutput {
  final File file;
  final int maxBytes;
  Future<void> _pending = Future.value();

  RotatingFileOutput({required this.file, this.maxBytes = 1024 * 1024});

  @override
  void output(OutputEvent event) {
    final data = utf8.encode('${event.lines.join('\n')}\n');
    _pending = _pending
        .then((_) async {
          await file.parent.create(recursive: true);
          if (await file.exists() &&
              await file.length() + data.length > maxBytes) {
            final previous = File('${file.path}.1');
            if (await previous.exists()) await previous.delete();
            await file.rename(previous.path);
          }
          await file.writeAsBytes(data, mode: FileMode.append, flush: true);
        })
        .catchError((Object error, StackTrace stack) {
          // Logging must never replace the original application error with an I/O
          // failure, and a failed write must not poison later writes.
          stderr.writeln('Could not write diagnostic log: $error');
        });
  }

  @override
  Future<void> destroy() => _pending;
}
