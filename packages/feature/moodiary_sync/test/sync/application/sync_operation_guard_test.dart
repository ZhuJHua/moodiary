import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/moodiary_sync.dart';

void main() {
  test('saving prevents sync before the first await', () async {
    final guard = SyncOperationGuard();
    final saved = Completer<int>();
    final saving = guard.runExclusive(() => saved.future);
    expect(guard.isBusy, isTrue);
    expect(await guard.tryRun(() => fail('sync ran while saving')), isNull);
    saved.complete(1);
    expect(await saving, 1);
    expect(guard.isBusy, isFalse);
  });

  test('sync rejects configuration changes and releases on failure', () async {
    final guard = SyncOperationGuard();
    final remote = Completer<int>();
    final syncing = guard.tryRun(() => remote.future);
    for (final operation in ['save', 'switch']) {
      await expectLater(
        guard.runExclusive(() => fail(operation)),
        throwsStateError,
      );
    }
    remote.completeError(StateError('sync failed'));
    await expectLater(syncing, throwsStateError);
    expect(await guard.runExclusive(() => 2), 2);
    await expectLater(
      guard.runExclusive(() => throw StateError('save failed')),
      throwsStateError,
    );
    expect(await guard.tryRun(() => 3), 3);
  });
}
