import 'package:synchronized/synchronized.dart';

final _mediaLock = Lock();

/// Serializes media staging-to-commit windows with media/cache cleanup.
///
/// This lock is not reentrant. Callers must not await another owner of it.
/// Cancellation belongs to the operation, not this shared filesystem lock.
Future<T> runMediaExclusive<T>(Future<T> Function() body) =>
    _mediaLock.synchronized(body);
