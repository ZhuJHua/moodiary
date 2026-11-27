import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'support/place_fixtures.dart';

class _StubPlaces extends PlaceController {
  _StubPlaces(this.places);

  final List<Place> places;

  @override
  Future<List<Place>> build() async => places;

  void setPlaces(List<Place> places) => state = AsyncData(places);
}

void main() {
  test('null ID does not subscribe to the place map', () {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [placeMapProvider.overrideWith((_) => fail('read place map'))],
    );
    expect(container.read(placeByIdProvider(null)), isNull);
  });

  test('the place map only rebuilds consumers of changed entries', () async {
    final home = make('a', 'Home');
    final work = make('b', 'Work');
    final controller = _StubPlaces([home, work]);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [placeControllerProvider.overrideWith(() => controller)],
    );
    await container.read(placeControllerProvider.future);

    final builds = <String, int>{};
    Provider<Place?> consumer(String id) => Provider((ref) {
      builds.update(id, (count) => count + 1, ifAbsent: () => 1);
      return ref.watch(placeByIdProvider(id));
    });

    final map = container.listen(placeMapProvider, (_, _) {});
    final homePlace = container.listen(consumer('a'), (_, _) {});
    final workPlace = container.listen(consumer('b'), (_, _) {});
    final missingPlace = container.listen(consumer('c'), (_, _) {});
    expect(map.read(), {'a': home, 'b': work});
    expect(homePlace.read(), same(home));
    expect(workPlace.read(), same(work));
    expect(missingPlace.read(), isNull);

    final renamed = home.copyWith(name: 'New name');
    controller.setPlaces([renamed, work]);
    await container.pump();
    expect(map.read(), {'a': renamed, 'b': work});
    expect(homePlace.read(), same(renamed));
    expect(builds, {'a': 2, 'b': 1, 'c': 1});

    controller.setPlaces([renamed]);
    await container.pump();
    expect(workPlace.read(), isNull);
    expect(builds, {'a': 2, 'b': 2, 'c': 1});
  });
}
