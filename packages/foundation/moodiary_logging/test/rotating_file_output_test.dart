import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:moodiary_logging/moodiary_logging.dart';

void main() {
  test(
    'rotates, overwrites the previous backup, and serializes later writes',
    () async {
      final root = Directory.systemTemp.createTempSync('rotating-log-');
      addTearDown(() => root.deleteSync(recursive: true));
      final file = File('${root.path}/error.log')
        ..writeAsStringSync('12345678');
      final old = File('${file.path}.1')..writeAsStringSync('old backup');
      final output = RotatingFileOutput(file: file, maxBytes: 10);
      void log(String message) =>
          output.output(OutputEvent(LogEvent(Level.error, message), [message]));
      log('abc');
      log('de');
      await output.destroy();
      expect(old.readAsStringSync(), '12345678');
      expect(file.readAsStringSync(), 'abc\nde\n');
      log('fgh');
      await output.destroy();
      expect(old.readAsStringSync(), 'abc\nde\n');
      expect(file.readAsStringSync(), 'fgh\n');
      expect(root.listSync().length, 2);
    },
  );
}
