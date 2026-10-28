import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_ml/moodiary_ml.dart';

void main() {
  test('storage whitelist includes all files from every live catalog', () {
    final names = liveModelFileNames();
    expect(names, isNotEmpty);
    for (final model in embeddingModelCatalog) {
      expect(
        names,
        containsAll([model.modelFileName, model.tokenizerFileName]),
      );
    }
    expect(names.any((name) => name.endsWith('.part')), isFalse);
    expect(
      names.any(
        (name) => retiredModelStems.any(
          (stem) => name == stem || name.startsWith('$stem.'),
        ),
      ),
      isFalse,
    );
    names.clear();
    expect(liveModelFileNames(), isNotEmpty);
    expect(retiredModelStems, contains('qwen3-0.6b-int8'));
  });
}
