import 'package:synchronized/synchronized.dart';

final _diaryWriteLocks = <String, Lock>{};

/// Serializes diary writes across MCP sessions.
Future<T> withDiaryWriteLock<T>(String id, Future<T> Function() action) async {
  final lock = _diaryWriteLocks.putIfAbsent(id, Lock.new);
  try {
    return await lock.synchronized(action);
  } finally {
    if (!lock.locked) _diaryWriteLocks.remove(id);
  }
}
