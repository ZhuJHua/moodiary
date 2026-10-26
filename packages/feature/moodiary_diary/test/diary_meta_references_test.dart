import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/application/diary_meta_references.dart';
import 'package:moodiary_models/moodiary_models.dart';

class _Categories implements CategoryRepository {
  final result = Completer<List<Category>>();
  final events = StreamController<CategoryEvent>.broadcast();

  @override
  Future<List<Category>> getAllCategories() => result.future;
  @override
  Stream<CategoryEvent> get categoryEvents => events.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Places implements PlaceRepository {
  final result = Completer<List<Place>>();

  @override
  Future<List<Place>> getAllPlaces() => result.future;
  @override
  Stream<PlaceEvent> get placeEvents => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Categories categories;
  late _Places places;
  late ProviderContainer container;
  final provider = diaryMetaReferencesProvider(categoryId: 'c', placeId: 'p');
  final category = Category(
    id: 'c',
    categoryName: 'Travel',
    lastModified: DateTime(2026),
  );
  final place = Place(
    id: 'p',
    name: 'Home',
    latitude: 0,
    longitude: 0,
    lastModified: DateTime(2026),
  );

  setUp(() {
    categories = _Categories();
    places = _Places();
    getIt.registerSingleton<CategoryRepository>(categories);
    getIt.registerSingleton<PlaceRepository>(places);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        // Ordering is irrelevant here; avoid initializing MMKV in this test.
        orderedPlacesProvider.overrideWith(
          (ref) => ref.watch(placeControllerProvider),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await categories.events.close();
    await getIt.reset();
  });

  test('cold references wait until both caches resolve', () async {
    container.listen(provider, (_, _) {});
    expect(container.read(provider).ready, isFalse);
    expect(container.read(provider).category, isNull);
    expect(container.read(provider).place, isNull);

    categories.result.complete([category]);
    await container.read(categoryControllerProvider.future);
    expect(container.read(provider).category, category);
    expect(container.read(provider).ready, isFalse);

    places.result.complete([place]);
    await container.read(placeControllerProvider.future);
    expect(container.read(provider).place, place);
    expect(container.read(provider).ready, isTrue);
  });

  test(
    'warm caches resolve on the first read without another async hop',
    () async {
      categories.result.complete([category]);
      places.result.complete([place]);
      await container.read(categoryControllerProvider.future);
      await container.read(placeControllerProvider.future);
      final meta = container.read(provider);
      expect(meta.ready, isTrue);
      expect(meta.category, category);
      expect(meta.place, place);

      container.listen(provider, (_, _) {});
      final renamed = category.copyWith(categoryName: 'Trips');
      categories.events.add(CategoryEvent.upserted(renamed));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).category, renamed);
      expect(container.read(provider).ready, isTrue);
    },
  );

  test('only assigned references need their cache to resolve', () async {
    final categoryOnly = diaryMetaReferencesProvider(categoryId: 'c');
    final placeOnly = diaryMetaReferencesProvider(placeId: 'p');
    container.listen(categoryOnly, (_, _) {});
    container.listen(placeOnly, (_, _) {});
    expect(container.read(categoryOnly).ready, isFalse);
    expect(container.read(placeOnly).ready, isFalse);

    categories.result.complete([category]);
    await container.read(categoryControllerProvider.future);
    expect(container.read(categoryOnly).ready, isTrue);
    expect(container.read(placeOnly).ready, isFalse);

    places.result.complete([place]);
    await container.read(placeControllerProvider.future);
    expect(container.read(placeOnly).ready, isTrue);
  });

  test('unassigned and deleted references are ready', () async {
    expect(container.read(diaryMetaReferencesProvider()).ready, isTrue);
    container.listen(provider, (_, _) {});
    categories.result.complete([]);
    places.result.complete([]);
    await container.read(categoryControllerProvider.future);
    await container.read(placeControllerProvider.future);
    final meta = container.read(provider);
    expect(meta.ready, isTrue);
    expect(meta.category, isNull);
    expect(meta.place, isNull);
  });

  test('failed reads are ready with missing references', () async {
    container.listen(provider, (_, _) {});
    final categoryRead = expectLater(
      container.read(categoryControllerProvider.future),
      throwsStateError,
    );
    final placeRead = expectLater(
      container.read(placeControllerProvider.future),
      throwsStateError,
    );
    categories.result.completeError(StateError('categories unavailable'));
    places.result.completeError(StateError('places unavailable'));
    await Future.wait([categoryRead, placeRead]);
    final meta = container.read(provider);
    expect(meta.ready, isTrue);
    expect(meta.category, isNull);
    expect(meta.place, isNull);
    expect(meta.places, isEmpty);
  });
}
