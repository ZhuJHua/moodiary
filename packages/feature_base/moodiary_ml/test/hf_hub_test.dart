import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_ml/moodiary_ml.dart';

void main() {
  group('HfHub.normalize', () {
    test('falls back to the official endpoint when blank', () {
      expect(HfHub.normalize('   '), HfHub.officialEndpoint);
    });

    test('adds HTTPS when no scheme is given', () {
      expect(HfHub.normalize('hf-mirror.com'), 'https://hf-mirror.com');
    });

    test('trims whitespace and trailing slashes', () {
      expect(
        HfHub.normalize('  https://hf-mirror.com//  '),
        'https://hf-mirror.com',
      );
    });

    test('keeps HTTP and the port', () {
      expect(
        HfHub.normalize('http://192.168.1.8:8080'),
        'http://192.168.1.8:8080',
      );
    });
  });
}
