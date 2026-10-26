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
  _WriteGate? updateGate;
  _WriteGate? insertGate;
  _WriteGate? deleteGate;

  @override
  Stream<DiaryEvent> get diaryEvents => const Stream.empty();

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
    stored = newDiary;
    writes.add(newDiary);
  }

  @override
  Future<void> insertADiary(
    Diary diary, {
    bool fromSync = false,
    IndexMode index = .inline,
  }) async {
    operations.add('insert');
    final gate = insertGate;
    insertGate = null;
    if (gate != null) await gate.wait();
    stored = diary;
    writes.add(diary);
  }

  @override
  Future<bool> hardDeleteDiary(String id) async {
    operations.add('delete');
    final gate = deleteGate;
    deleteGate = null;
    if (gate != null) await gate.wait();
    stored = null;
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

    expect(await saving, DraftSaveResult.saved);
    expect(container.read(provider).value?.content, 'B');
    expect(observed, isNot(contains('A')));
    expect(repository.writes.map((d) => d.content), ['A', 'B']);
    expect(repository.indexes, [IndexMode.inline, IndexMode.inline]);

    expect(await controller.autoSave(), DraftSaveResult.saved);
    expect(repository.stored?.content, 'B');
    expect(repository.indexes.last, IndexMode.skip);
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
    expect(repository.indexes, [IndexMode.inline]);
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
}
