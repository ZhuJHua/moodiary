import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_ml/moodiary_ml.dart';

void main() {
  test(
    'live catalog is kept; retired, unknown, and partial files are classified',
    () async {
      final root = Directory.systemTemp.createTempSync('stray-models-');
      addTearDown(() => root.deleteSync(recursive: true));
      final spec = embeddingModelCatalog.first;
      final names = [
        spec.modelFileName,
        spec.tokenizerFileName,
        'qwen3-0.6b-int8.onnx',
        'qwen3-0.6b-int8.tokenizer.json',
        'mystery.bin',
        '${spec.modelFileName}.part',
      ];
      for (final name in names) {
        File('${root.path}/$name').writeAsBytesSync([1, 2, 3]);
      }
      final stray = await strayModelFiles(modelPath: root.path);
      expect(stray.length, 4);
      expect(stray.every((f) => f.bytes == 3), isTrue);
      expect(stray.where((f) => f.kind == .retiredMood).length, 2);
      expect(
        stray.singleWhere((f) => f.kind == .unused).path,
        endsWith('mystery.bin'),
      );
      expect(
        stray.singleWhere((f) => f.kind == .partial).path,
        endsWith('.part'),
      );
      expect(
        stray.map((f) => f.path),
        isNot(contains('${root.path}/${spec.modelFileName}')),
      );
    },
  );
}
