import 'package:moodiary/common/values/sync_status.dart';

class SyncResult<T> {
  final SyncStatus status;
  T? data;

  SyncResult({
    required this.status,
    this.data,
  });
}
