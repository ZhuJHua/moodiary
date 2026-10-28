import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_mobile/app/settings/storage/storage_controller.dart';
import 'package:moodiary_sync/moodiary_sync.dart';

class _Runner implements SyncRunner {
  @override
  final ValueNotifier<SyncStatus> status = ValueNotifier(const SyncStatus());
  @override
  bool get isRunning => status.value.isRunning;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SyncController extends SyncController {
  @override
  SyncState build() => const SyncState.idle();
}

void main() {
  tearDown(getIt.reset);
  test(
    'running sync disables cache even when the page opens mid-sync',
    () async {
      final runner = _Runner();
      getIt.registerSingleton<SyncRunner>(runner);
      addTearDown(runner.status.dispose);
      runner.status.value = SyncStatus(
        running: SyncActivity(
          trigger: .manual,
          direction: .sync,
          startedAt: DateTime(2026),
          backendName: 'test',
        ),
      );
      final events = StreamController<StorageScanProgress>.broadcast();
      addTearDown(events.close);
      final container = ProviderContainer.test(
        overrides: [
          storageUsageProvider.overrideWith((ref) => events.stream),
          syncControllerProvider.overrideWith(_SyncController.new),
        ],
      );
      container.listen(storageControllerProvider, (_, _) {});
      await container.pump();
      events.add(
        const StorageScanProgress(
          bytes: {StorageArea.cache: 123},
          done: {StorageArea.cache},
          area: .cache,
          files: 1,
          reclaimableCacheBytes: 123,
        ),
      );
      await container.pump();
      var state = container.read(storageControllerProvider);
      expect(state.items.singleWhere((i) => i.kind == .cache).busy, isTrue);
      expect(state.selectedBytes, 0);
      expect(
        await container.read(storageControllerProvider.notifier).clean(),
        0,
      );
      runner.status.value = const SyncStatus();
      state = container.read(storageControllerProvider);
      expect(state.items.singleWhere((i) => i.kind == .cache).busy, isFalse);
      expect(state.selectedBytes, 123);
    },
  );
}
