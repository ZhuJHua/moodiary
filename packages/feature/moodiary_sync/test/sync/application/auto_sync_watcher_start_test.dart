import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:moodiary_sync/src/data/sync_cancellation.dart';

class _Storage extends IKVStorage {
  int reads = 0;
  @override
  Future<void> init() async {}
  @override
  T? get<T extends Object>(String key) {
    if (key == MoodiaryKVs.syncPollInterval.name) reads++;
    return null;
  }
}

class _Diary extends Fake implements DiaryRepository {
  @override
  Stream<DiaryEvent> get diaryEvents => const Stream.empty();
}

class _Tag extends Fake implements TagRepository {
  @override
  Stream<TagEvent> get tagEvents => const Stream.empty();
}

class _Category extends Fake implements CategoryRepository {
  @override
  Stream<CategoryEvent> get categoryEvents => const Stream.empty();
}

class _Place extends Fake implements PlaceRepository {
  @override
  Stream<PlaceEvent> get placeEvents => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('starting twice registers only one interval listener', () async {
    final storage = _Storage();
    getIt.registerSingleton<IKVStorage>(storage);
    addTearDown(getIt.reset);
    final logger = SyncLogger.memory();
    final watcher = AutoSyncWatcher.withDependencies(
      logger,
      SyncRunner(SyncCancellation(), logger),
      _Diary(),
      _Category(),
      _Tag(),
      _Place(),
      SyncDirtyTracker(),
      OpenDiaryRegistry(),
      onlineChanges: () => const Stream.empty(),
    );
    addTearDown(watcher.dispose);
    watcher.start();
    watcher.start();
    final before = storage.reads;
    MoodiaryKVs.syncPollInterval.set(90);
    expect(storage.reads - before, 1);
  });
}
