import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_ml/moodiary_ml.dart';

void main() {
  group('HfHub.resolveWith', () {
    const hfPath = 'org/model/resolve/main/model.onnx';

    for (final endpoint in ['', '   ']) {
      test('uses the official endpoint for "$endpoint"', () {
        expect(
          HfHub.resolveWith(endpoint, hfPath),
          'https://huggingface.co/$hfPath',
        );
      });
    }

    test('adds HTTPS when no scheme is given', () {
      expect(
        HfHub.resolveWith('hf-mirror.com', hfPath),
        'https://hf-mirror.com/$hfPath',
      );
    });

    test('trims whitespace and removes all trailing slashes', () {
      expect(
        HfHub.resolveWith('  https://hf-mirror.com//  ', hfPath),
        'https://hf-mirror.com/$hfPath',
      );
    });

    test('preserves HTTP and the port', () {
      expect(
        HfHub.resolveWith('http://192.168.1.8:8080', hfPath),
        'http://192.168.1.8:8080/$hfPath',
      );
    });
  });
}
