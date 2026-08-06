import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';

class _StubCategories extends CategoryController {
  _StubCategories(this._cats);
  final List<Category> _cats;
  @override
  Future<List<Category>> build() async => _cats;
}

void main() {
  Category cat(String id, String name) =>
      Category(id: id, categoryName: name, lastModified: DateTime(2026));

  ProviderContainer containerWith(List<Category> cats) => ProviderContainer(
    overrides: [
      categoryControllerProvider.overrideWith(() => _StubCategories(cats)),
    ],
  );

  test('resolves a category by id', () async {
    final c = containerWith([cat('a', 'work'), cat('b', 'life')]);
    addTearDown(c.dispose);
    await c.read(categoryControllerProvider.future);
    expect(c.read(categoryByIdProvider('b'))?.categoryName, 'life');
  });

  test('returns null for null id or missing id', () async {
    final c = containerWith([cat('a', 'work')]);
    addTearDown(c.dispose);
    await c.read(categoryControllerProvider.future);
    expect(c.read(categoryByIdProvider(null)), isNull);
    expect(c.read(categoryByIdProvider('zzz')), isNull);
  });
}
