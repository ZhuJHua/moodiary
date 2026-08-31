import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_ml/moodiary_ml.dart';

void main() {
  test('嵌入清单字段完整且 id 唯一', () {
    expect(embeddingModelCatalog, isNotEmpty);
    final ids = embeddingModelCatalog.map((s) => s.id).toSet();
    expect(ids.length, embeddingModelCatalog.length);
    for (final spec in embeddingModelCatalog) {
      expect(spec.dim, greaterThan(0));
      expect(spec.modelFileName, endsWith('.onnx'));
      expect(spec.tokenizerFileName, endsWith('.tokenizer.json'));
      // 镜像与官方共用仓内路径：不带协议与主机。
      for (final path in [spec.modelHfPath, spec.tokenizerHfPath]) {
        expect(path, isNot(startsWith('http')));
        expect(path, contains('/resolve/'));
      }
      expect(spec.sizeBytes, greaterThan(0));
      expect(spec.padToken, isNotEmpty);
    }
  });

  test('byId 往返与未知 id', () {
    final spec = embeddingModelCatalog.first;
    expect(EmbeddingModelManager.byId(spec.id), same(spec));
    expect(EmbeddingModelManager.byId('nope'), isNull);
    expect(EmbeddingModelManager.byId(''), isNull);
  });

  test('心情建议清单字段完整且 id 唯一', () {
    expect(moodLlmCatalog, isNotEmpty);
    final ids = moodLlmCatalog.map((s) => s.id).toSet();
    expect(ids.length, moodLlmCatalog.length);
    for (final spec in moodLlmCatalog) {
      expect(spec.modelFileName, endsWith('.onnx'));
      expect(spec.tokenizerFileName, endsWith('.tokenizer.json'));
      for (final path in [spec.modelHfPath, spec.tokenizerHfPath]) {
        expect(path, isNot(startsWith('http')));
        expect(path, contains('/resolve/'));
      }
      expect(spec.sizeBytes, greaterThan(0));
      // 与嵌入清单不撞文件名（两类模型共用 model/ 目录）。
      expect(embeddingModelCatalog.map((e) => e.id), isNot(contains(spec.id)));
    }
  });

  test('moodLlm byId 往返与未知 id', () {
    final spec = moodLlmCatalog.first;
    expect(MoodLlmModelManager.byId(spec.id), same(spec));
    expect(MoodLlmModelManager.byId('nope'), isNull);
    expect(MoodLlmModelManager.byId(''), isNull);
  });
}
