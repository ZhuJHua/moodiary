import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/application/search_controller.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  late MoodiaryDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    final repository = DiaryRepository(db);
    await repository.insertDiaries([
      for (var i = 0; i < 40; i++)
        Diary.create(
          title: '第 $i 篇',
          content: '',
          contentText: '今天吃了一个苹果',
          mood: .neutral,
          imageName: const [],
          audioName: const [],
          videoName: const [],
          tags: const [],
          type: .tiptap,
        ),
    ]);
    getIt.registerSingleton<DiaryRepository>(repository);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await getIt.reset();
    await db.close();
  });

  test('换查询会作废在途的 loadMore，不会把分页卡死', () async {
    final controller = container.read(diarySearchControllerProvider.notifier);
    await controller.search('苹果');
    expect(container.read(diarySearchControllerProvider).totalCount, 40);
    expect(container.read(diarySearchControllerProvider).hasMore, isTrue);

    final pending = controller.loadMore();
    await controller.search('苹果');
    await pending;

    final state = container.read(diarySearchControllerProvider);
    expect(state.isLoadingMore, isFalse, reason: '过期的 loadMore 不清标志');
    expect(state.results, hasLength(30));

    await controller.loadMore();
    expect(container.read(diarySearchControllerProvider).results, hasLength(40));
  });
}
