import 'package:moodiary_files/moodiary_files.dart';

import 'sync_cancellation_token.dart';

Future<T> runSyncExclusive<T>(
  SyncCancellationToken cancellation,
  Future<T> Function(SyncCancellationToken) operation,
) => runMediaExclusive(() => operation(cancellation));
