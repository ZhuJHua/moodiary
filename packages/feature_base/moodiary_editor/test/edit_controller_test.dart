import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/src/application/edit_controller.dart';
import 'package:moodiary_models/moodiary_models.dart';

class _WriteGate {
  final started = Completer<void>();
  final release = Completer<void>();

  Future<void> wait() {
    started.complete();
    return release.future;
  }
}

class _Repository implements DiaryRepository {
  Diary? stored;
  final writes = <Diary>[];
  final indexes = <IndexMode>[];
  final operations = <String>[];
  final events = StreamController<DiaryEvent>.broadcast();
  Duration? writeLatency;
  _WriteGate? updateGate;
  _WriteGate? insertGate;
  _WriteGate? deleteGate;

  @override
  Stream<DiaryEvent> get diaryEvents => events.stream;

  @override
  Future<Diary?> getDiaryByBusinessId(String id) async => stored;

  @override
  Future<void> updateADiary({
    required Diary newDiary,
    IndexMode index = .inline,
    bool fromSync = false,
  }) async {
    operations.add('update');
    indexes.add(index);
    final gate = updateGate;
    updateGate = null;
    if (gate != null) await gate.wait();
    if (writeLatency case final latency?) await Future<void>.delayed(latency);
    stored = newDiary;
    writes.add(newDiary);
    events.add(DiaryUpdated(newDiary));
  }

  @override
  Future<void> insertADiary(
    Diary diary, {
    bool fromSync = false,
    IndexMode index = .inline,
  }) async {
    operations.add('insert');
    indexes.add(index);
    final gate = insertGate;
    insertGate = null;
    if (gate != null) await gate.wait();
    if (writeLatency case final latency?) await Future<void>.delayed(latency);
    stored = diary;
    writes.add(diary);
    events.add(DiaryCreated(diary));
  }

  @override
  Future<bool> hardDeleteDiary(String id) async {
    operations.add('delete');
    final gate = deleteGate;
    deleteGate = null;
    if (gate != null) await gate.wait();
    if (writeLatency case final latency?) await Future<void>.delayed(latency);
    stored = null;
    events.add(DiaryDeleted(id));
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Repository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _Repository();
    getIt.registerSingleton<DiaryRepository>(repository);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await repository.events.close();
    await getIt.reset();
  });

  Future<EditControllerProvider> open({bool existing = true}) async {
    final diary = Diary.empty(type: .markdown)
        .copyWith(content: 'B', contentText: 'B');
    if (existing) repository.stored = diary;
    final provider = editControllerProvider(
      existing ? diary.id : null,
      defaultType: .markdown,
    );
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
    return provider;
  }

  test('写入 A 时收到 B，状态不回退并在返回前保存 B', () async {
    final provider = await open();
    final controller = container.read(provider.notifier);
    final gate = _WriteGate();
    repository.writeLatency = const Duration(milliseconds: 5);
    repository.updateGate = gate;
    controller.changeContent('A');
    final saving = controller.autoSave();
    await gate.started.future;

    controller.changeContent('B');
    final observed = <String>[];
    container.listen(provider, (_, next) {
      if (next.value case final diary?) observed.add(diary.content);
    });
    gate.release.complete();

    expect(
      await saving.timeout(const Duration(seconds: 1)),
      DraftSaveResult.saved,
    );
    expect(container.read(provider).value?.content, 'B');
    expect(observed, isNot(contains('A')));
    expect(repository.writes.map((d) => d.content), ['A', 'B']);
    expect(repository.indexes, [IndexMode.inline, IndexMode.inline]);

    expect(await controller.autoSave(), DraftSaveResult.saved);
    expect(repository.stored?.content, 'B');
    expect(repository.writes, hasLength(2));
    expect(repository.indexes, [IndexMode.inline, IndexMode.inline]);
  });

  test('写入期间的标题修改保留并重新索引', () async {
    final provider = await open();
    final controller = container.read(provider.notifier);
    final gate = _WriteGate();
    repository.updateGate = gate;
    controller.changeTitle('A');
    final saving = controller.autoSave();
    await gate.started.future;

    controller.changeTitle('');
    gate.release.complete();

    expect(await saving, DraftSaveResult.saved);
    expect(container.read(provider).value?.title, '');
    expect(repository.writes.map((d) => d.title), ['A', '']);
    expect(repository.indexes, [IndexMode.inline, IndexMode.inline]);
  });

  test('追加保存失败时保留 B，重试仍按已写入的 A 判断索引', () async {
    final provider = await open();
    final controller = container.read(provider.notifier);
    final first = _WriteGate();
    repository.updateGate = first;
    controller.changeContent('A');
    final saving = controller.autoSave();
    await first.started.future;

    controller.changeContent('B');
    final second = _WriteGate();
    repository.updateGate = second;
    first.release.complete();
    await second.started.future;
    expect(container.read(provider).value?.content, 'B');
    second.release.completeError(StateError('write failed'));

    expect(await saving, DraftSaveResult.failed);
    expect(container.read(provider).value?.content, 'B');
    expect(repository.stored?.content, 'A');
    expect(await controller.autoSave(), DraftSaveResult.saved);
    expect(repository.stored?.content, 'B');
    expect(repository.indexes, [
      IndexMode.inline,
      IndexMode.inline,
      IndexMode.inline,
    ]);
  });

  test('新草稿插入 A 时收到 B，后续更新保存 B', () async {
    final provider = await open(existing: false);
    final controller = container.read(provider.notifier);
    final gate = _WriteGate();
    repository.insertGate = gate;
    controller.changeContent('A');
    final saving = controller.autoSave();
    await gate.started.future;

    controller.changeContent('B');
    gate.release.complete();

    expect(await saving, DraftSaveResult.saved);
    expect(container.read(provider).value?.content, 'B');
    expect(repository.operations, ['insert', 'update']);
    expect(repository.writes.map((d) => d.content), ['A', 'B']);
    expect(repository.indexes, [IndexMode.inline, IndexMode.inline]);
  });

  test('空白新草稿删除期间收到 B，重新插入而不是更新', () async {
    final provider = await open(existing: false);
    final controller = container.read(provider.notifier);
    controller.changeContent('A');
    expect(await controller.autoSave(), DraftSaveResult.saved);

    final gate = _WriteGate();
    repository.deleteGate = gate;
    controller.changeContent('');
    final saving = controller.autoSave();
    await gate.started.future;

    controller.changeContent('B');
    gate.release.complete();

    expect(await saving, DraftSaveResult.saved);
    expect(container.read(provider).value?.content, 'B');
    expect(repository.operations, ['insert', 'delete', 'insert']);
    expect(repository.stored?.content, 'B');
    expect(repository.writes.map((d) => d.content), ['A', 'B']);
  });

  test('没有变化时重复保存不再写入', () async {
    final provider = await open();
    final controller = container.read(provider.notifier);
    controller.changeContent('A');

    expect(await controller.autoSave(), DraftSaveResult.saved);
    expect(await controller.autoSave(), DraftSaveResult.saved);
    controller.changeContent('A');
    expect(await controller.autoSave(), DraftSaveResult.saved);

    expect(repository.writes, hasLength(1));
    expect(repository.stored?.content, 'A');
  });

  test('新草稿清空后重建相同内容仍执行索引', () async {
    final provider = await open(existing: false);
    final controller = container.read(provider.notifier);
    controller.changeContent('A');
    expect(await controller.autoSave(), DraftSaveResult.saved);

    controller.changeContent('');
    expect(await controller.autoSave(), DraftSaveResult.saved);
    expect(repository.stored, isNull);
    controller.changeContent('A');
    expect(await controller.autoSave(), DraftSaveResult.saved);

    expect(repository.operations, ['insert', 'delete', 'insert']);
    expect(repository.indexes, [IndexMode.inline, IndexMode.inline]);
    expect(repository.stored?.content, 'A');
  });

  test('仅元数据变化时不重建索引', () async {
    final provider = await open();
    final controller = container.read(provider.notifier);
    controller.changeTags(['tag']);

    expect(await controller.autoSave(), DraftSaveResult.saved);
    expect(repository.indexes, [IndexMode.skip]);
    expect(repository.stored?.tags, ['tag']);
  });

  test('同步 upsert 已打开的日记后只改标签，保存保留同步正文', () async {
    final provider = await open();
    final controller = container.read(provider.notifier);
    await repository.insertADiary(
      repository.stored!.copyWith(content: 'synced', contentText: 'synced'),
      fromSync: true,
    );
    await pumpEventQueue();

    expect(container.read(provider).value?.content, 'synced');
    controller.changeTags(['tag']);
    expect(await controller.autoSave(), DraftSaveResult.saved);
    expect(repository.stored?.content, 'synced');
    expect(repository.stored?.tags, ['tag']);
  });

  test('没有本地编辑时采纳外部更新并同步保存快照', () async {
    final provider = await open();
    final controller = container.read(provider.notifier);
    final external = repository.stored!.copyWith(
      content: 'external',
      contentText: 'external',
      title: 'external title',
    );
    await repository.updateADiary(newDiary: external);
    await pumpEventQueue();

    expect(container.read(provider).value, same(external));
    expect(await controller.autoSave(), DraftSaveResult.saved);
    expect(repository.writes, hasLength(1));
  });

  test('有未保存的本地编辑时忽略外部更新', () async {
    final provider = await open();
    final controller = container.read(provider.notifier);
    controller.changeContent('local');
    await repository.updateADiary(
      newDiary: repository.stored!.copyWith(
        content: 'external',
        contentText: 'external',
      ),
    );
    await pumpEventQueue();

    expect(container.read(provider).value?.content, 'local');
    expect(await controller.autoSave(), DraftSaveResult.saved);
    expect(repository.stored?.content, 'local');
  });

  test('写入进行中忽略外部更新', () async {
    final provider = await open();
    final controller = container.read(provider.notifier);
    controller.changeContent('local');
    final gate = _WriteGate();
    repository.updateGate = gate;
    final saving = controller.autoSave();
    await gate.started.future;
    await repository.updateADiary(
      newDiary: repository.stored!.copyWith(
        content: 'external',
        contentText: 'external',
      ),
    );
    await pumpEventQueue();

    expect(container.read(provider).value?.content, 'local');
    gate.release.complete();
    expect(await saving, DraftSaveResult.saved);
    expect(repository.stored?.content, 'local');
    expect(repository.writes, hasLength(2));
  });

  test('忽略其他日记的更新和删除事件', () async {
    final provider = await open();
    final initial = container.read(provider).value;
    final other = Diary.empty(type: .markdown);
    repository.events.add(DiaryUpdated(other));
    repository.events.add(DiaryDeleted(other.id));
    await pumpEventQueue();

    expect(container.read(provider).value, same(initial));
    expect(container.read(provider).hasError, isFalse);
  });

  test('收到删除事件后进入错误状态', () async {
    final provider = await open();
    await repository.hardDeleteDiary(repository.stored!.id);
    await pumpEventQueue();

    expect(container.read(provider).hasError, isTrue);
    expect(container.read(provider).error, isA<StateError>());
  });
}
