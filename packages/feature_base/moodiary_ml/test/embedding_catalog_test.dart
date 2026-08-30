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

  test('情感清单字段完整', () {
    expect(sentimentModelCatalog, isNotEmpty);
    for (final spec in sentimentModelCatalog) {
      expect(spec.modelFileName, endsWith('.onnx'));
      expect(spec.labels.length, greaterThan(1));
      expect(spec.labels.toSet().length, spec.labels.length);
      for (final path in [spec.modelHfPath, spec.tokenizerHfPath]) {
        expect(path, isNot(startsWith('http')));
        expect(path, contains('/resolve/'));
      }
    }
  });

  test('byId 往返与未知 id', () {
    final spec = embeddingModelCatalog.first;
    expect(EmbeddingModelManager.byId(spec.id), same(spec));
    expect(EmbeddingModelManager.byId('nope'), isNull);
    expect(EmbeddingModelManager.byId(''), isNull);
    expect(
      SentimentModelManager.byId(sentimentModelCatalog.first.id),
      same(sentimentModelCatalog.first),
    );
  });
}
