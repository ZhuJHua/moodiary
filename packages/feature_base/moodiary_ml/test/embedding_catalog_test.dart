import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_ml/moodiary_ml.dart';

void main() {
  test('清单项字段完整且 id 唯一', () {
    expect(embeddingModelCatalog, isNotEmpty);
    final ids = embeddingModelCatalog.map((s) => s.id).toSet();
    expect(ids.length, embeddingModelCatalog.length);
    for (final spec in embeddingModelCatalog) {
      expect(spec.dim, greaterThan(0));
      expect(spec.fileName, endsWith('.gguf'));
      // 镜像与官方共用仓内路径：不带协议与主机。
      expect(spec.hfPath, isNot(startsWith('http')));
      expect(spec.hfPath, contains('/resolve/'));
      expect(spec.sizeBytes, greaterThan(0));
    }
  });

  test('byId 往返与未知 id', () {
    final spec = embeddingModelCatalog.first;
    expect(EmbeddingModelManager.byId(spec.id), same(spec));
    expect(EmbeddingModelManager.byId('nope'), isNull);
    expect(EmbeddingModelManager.byId(''), isNull);
  });
}
