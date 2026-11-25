import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';

import 'sync_cancellation.dart';

Future<T> runSyncExclusive<T>(
  Future<T> Function() body, {
  SyncCancellation? cancellation,
}) => runMediaExclusive(() async {
  try {
    return await body();
  } finally {
    (cancellation ?? getIt<SyncCancellation>()).reset();
  }
});
