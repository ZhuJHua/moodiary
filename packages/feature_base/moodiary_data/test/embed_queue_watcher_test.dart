import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

class _Repository implements DiaryRepository {
  final events = StreamController<DiaryEvent>.broadcast();

  @override
  Stream<DiaryEvent> get diaryEvents => events.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Index implements EmbedIndexService {
  int drains = 0;

  @override
  Future<int> drain({int? maxDiaries}) async {
    drains++;
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Repository repository;
  late _Index index;
  late OpenDiaryRegistry openDiaries;
  late EmbedQueueWatcher watcher;

  setUp(() {
    repository = _Repository();
    index = _Index();
    openDiaries = OpenDiaryRegistry();
    watcher = EmbedQueueWatcher(repository, index, openDiaries);
  });

  tearDown(() async {
    await watcher.dispose();
    await repository.events.close();
  });

  testWidgets('结束编辑后防抖排空，无需新的日记事件', (tester) async {
    watcher.start();
    watcher.start();
    openDiaries.setEditing('d1', editing: true);
    openDiaries.open('d1');
    openDiaries.close('d1');
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(index.drains, 0);

    openDiaries.setEditing('d1', editing: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    expect(index.drains, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(index.drains, 1);
  });

  testWidgets('日记写入与结束编辑共用防抖，只排空一次', (tester) async {
    watcher.start();
    openDiaries.setEditing('d1', editing: true);
    repository.events.add(DiaryUpdated(Diary.empty(type: .markdown)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));

    openDiaries.setEditing('d1', editing: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(index.drains, 0);
    await tester.pump(const Duration(seconds: 4));
    expect(index.drains, 1);
  });

  testWidgets('释放时取消定时器和两个事件订阅', (tester) async {
    watcher.start();
    openDiaries.setEditing('d1', editing: true);
    openDiaries.setEditing('d2', editing: true);
    repository.events.add(DiaryUpdated(Diary.empty(type: .markdown)));
    await tester.pump();
    openDiaries.setEditing('d1', editing: false);
    await tester.runAsync(watcher.dispose);

    openDiaries.setEditing('d2', editing: false);
    repository.events.add(DiaryUpdated(Diary.empty(type: .markdown)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    expect(index.drains, 0);
  });
}
