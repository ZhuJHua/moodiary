import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository repo;
  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    repo = DiaryRepository(db);
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
  });
  Diary makeDiary(String id, String text, {List<String> tagIds = const []}) =>
      Diary.empty(type: .markdown)
          .copyWith(id: id, content: text, tagIds: tagIds);
  test('标签列表跟随日记和标签事件更新', () async {
    final tags = TagRepository(db);
    final first = Tag.create('Trip');
    final second = Tag.create('Trip');
    await tags.insertATag(first);
    await tags.insertATag(second);
    final diary = makeDiary('a', '一');
    await repo.insertADiary(diary);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        diaryRepositoryProvider.overrideWithValue(repo),
        tagRepositoryProvider.overrideWithValue(tags),
      ],
    );
    final provider = diaryControllerProvider(tagName: 'Trip');
    container.listen(provider, (_, _) {});
    expect(await container.read(provider.future), isEmpty);

    Future<List<String>> ids() async {
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      return (await container.read(provider.future)).map((d) => d.id).toList();
    }

    await repo.updateADiary(newDiary: diary.copyWith(tagIds: [second.id]));
    expect(await ids(), ['a']);
    await repo.updateADiary(newDiary: diary);
    expect(await ids(), isEmpty);
    await repo.updateADiary(newDiary: diary.copyWith(tagIds: [first.id]));
    expect(await ids(), ['a']);
    await tags.renameTag('Trip', 'Travel');
    expect(await ids(), isEmpty);
    await tags.renameTag('Travel', 'Trip');
    expect(await ids(), ['a']);
  });

  test('unrelated tag events preserve loaded diary pages', () async {
    final tags = TagRepository(db);
    final trip = Tag.create('Trip');
    await tags.insertATag(trip);
    await repo.insertDiaries([
      for (var index = 0; index < 31; index++)
        makeDiary('extra-$index', '二', tagIds: [trip.id]),
    ]);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        diaryRepositoryProvider.overrideWithValue(repo),
        tagRepositoryProvider.overrideWithValue(tags),
      ],
    );
    final provider = diaryControllerProvider(tagName: trip.name);
    container.listen(provider, (_, _) {});
    expect(await container.read(provider.future), hasLength(30));
    await container.read(provider.notifier).loadMore();
    final pages = await container.read(provider.future);
    expect(pages, hasLength(31));
    await tags.insertATag(Tag.create('Unrelated'));
    await Future<void>.delayed(Duration.zero);
    await tags.getAllTags();
    await container.pump();
    expect(await container.read(provider.future), same(pages));
  });

  test('recycle bin clear finishes all deletes after listener leaves', () async {
    final firstDeleteStarted = Completer<void>();
    final allowFirstDelete = Completer<void>();
    final deletedIds = <String>[];
    final fakeRepo = _DelayedDeleteRepo(
      entries: [
        makeDiary('r1', 'one').copyWith(show: false),
        makeDiary('r2', 'two').copyWith(show: false),
        makeDiary('r3', 'three').copyWith(show: false),
      ],
      onDelete: (id) async {
        if (id == 'r1') {
          firstDeleteStarted.complete();
          await allowFirstDelete.future;
        }
        deletedIds.add(id);
        return true;
      },
    );
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [diaryRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    final sub = container.listen(recycleBinDiariesProvider, (_, _) {});
    expect(await container.read(recycleBinDiariesProvider.future), hasLength(3));

    final clearing = container.read(recycleBinDiariesProvider.notifier).clear();
    await firstDeleteStarted.future;
    // Simulate leaving the recycle bin route while deletion is in flight.
    sub.close();
    await container.pump();
    allowFirstDelete.complete();

    expect(await clearing, 3);
    expect(deletedIds, ['r1', 'r2', 'r3']);
  });
}

class _DelayedDeleteRepo extends Fake implements DiaryRepository {
  _DelayedDeleteRepo({required this.entries, required this.onDelete});

  final List<Diary> entries;
  final Future<bool> Function(String id) onDelete;

  @override
  Stream<DiaryEvent> get diaryEvents => const Stream.empty();

  @override
  Future<List<Diary>> getRecycleBinDiaries() async => entries;

  @override
  Future<bool> deleteADiary(String id) => onDelete(id);
}
