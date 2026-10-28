import 'package:moodiary_di/moodiary_di.dart';
import 'package:synchronized/synchronized.dart';

import 'sync_cancellation.dart';

final _syncFamilyLock = Lock();

Future<T> runSyncExclusive<T>(Future<T> Function() body) =>
    _syncFamilyLock.synchronized(() async {
      try {
        return await body();
      } finally {
        getIt<SyncCancellation>().reset();
      }
    });
