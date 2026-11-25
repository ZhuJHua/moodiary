import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/moodiary_diary.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository repo;
  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    repo = DiaryRepository(db);
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
  });
  tearDown(() => db.close());
  tearDown(getIt.reset);
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
    getIt.registerSingleton<DiaryRepository>(repo);
    getIt.registerSingleton<TagRepository>(tags);
    final container = ProviderContainer();
    addTearDown(container.dispose);
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
    getIt.registerSingleton<DiaryRepository>(repo);
    getIt.registerSingleton<TagRepository>(tags);
    final container = ProviderContainer();
    addTearDown(container.dispose);
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
}
