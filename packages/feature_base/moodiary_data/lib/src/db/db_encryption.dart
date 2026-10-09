import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:meta/meta.dart' show internal;
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_simple/sqlite3_simple.dart';

@internal
enum DatabaseFileState { missing, plaintext, encrypted }

const String encryptingSuffix = '.encrypting';

@internal
const int maxEncryptFailures = 3;

const String _plainHeader = 'SQLite format 3\u0000';

final RegExp _keyPattern = RegExp(r'^[0-9a-f]{64}$');

@internal
DatabaseFileState databaseFileState(String path) {
  final file = File(path);
  if (!file.existsSync() || file.lengthSync() < _plainHeader.length) {
    return .missing;
  }
  final raf = file.openSync();
  try {
    final header = String.fromCharCodes(raf.readSync(_plainHeader.length));
    return header == _plainHeader ? .plaintext : .encrypted;
  } finally {
    raf.closeSync();
  }
}

/// 加密库配不上密钥一律是启动失败，由用户决定是否清空；绝不静默换新密钥。
sealed class DatabaseKeyError extends Error {}

final class DatabaseKeyLost extends DatabaseKeyError {
  @override
  String toString() =>
      'DatabaseKeyLost: the database is encrypted but secure storage holds '
      'no key for it';
}

final class DatabaseKeyUnavailable extends DatabaseKeyError {
  final Object cause;

  DatabaseKeyUnavailable(this.cause);

  @override
  String toString() => 'DatabaseKeyUnavailable: $cause';
}

final class DatabaseKeyMismatch extends DatabaseKeyError {
  @override
  String toString() =>
      'DatabaseKeyMismatch: the database cannot be read with the stored key';
}

@internal
sealed class DatabaseKey {
  const DatabaseKey();
}

/// 从安全存储读回来的密钥，已经证明落盘，可以用来加密已有数据。
final class DatabaseKeyStored extends DatabaseKey {
  final String key;

  const DatabaseKeyStored(this.key);
}

/// 本次启动刚生成并写入的密钥。Android 上 write 走 apply()，返回时未必已落盘，
/// 所以当次不拿它加密已有数据，下次读回来再加密。
final class DatabaseKeyFresh extends DatabaseKey {
  final String key;

  const DatabaseKeyFresh(this.key);
}

final class DatabaseKeyFailed extends DatabaseKey {
  final Object cause;

  const DatabaseKeyFailed(this.cause);
}

@internal
String newDatabaseKey() {
  final random = Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 32; i++) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

@internal
Future<DatabaseKey> resolveDatabaseKey({
  required DatabaseFileState fileState,
}) async {
  final String? stored;
  try {
    // 只有加密库才值得为瞬时的 Keystore 抖动重试；明文库读不到就按明文开
    stored = fileState == .encrypted
        ? await _readWithRetry()
        : await MoodiarySecureKVs.databaseKey.get();
  } catch (e) {
    return DatabaseKeyFailed(e);
  }
  if (stored != null && _keyPattern.hasMatch(stored)) {
    return DatabaseKeyStored(stored);
  }
  if (fileState == .encrypted) {
    if (stored == null) throw DatabaseKeyLost();
    return DatabaseKeyFailed(StateError('stored database key is malformed'));
  }
  // 没有加密数据依赖旧值，格式不对就换一把
  final key = newDatabaseKey();
  try {
    await MoodiarySecureKVs.databaseKey.set(key);
  } catch (e) {
    return DatabaseKeyFailed(e);
  }
  return DatabaseKeyFresh(key);
}

Future<String?> _readWithRetry() async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await MoodiarySecureKVs.databaseKey.get();
    } catch (_) {
      if (attempt == 3) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
    }
  }
}

/// 原始密钥（x'…'）跳过 KDF；自动扩展在 PRAGMA key 之前跑，分词器要在这之后补注册。
/// 未知 PRAGMA 会被 SQLite 静默忽略，所以必须确认宿主真的是 SQLCipher。
@internal
void applyDatabaseKey(Database db, String key) {
  try {
    db.execute('PRAGMA key = "x\'$key\'"');
  } on SqliteException catch (e) {
    throw StateError('PRAGMA key failed: ${e.extendedResultCode} ${e.message}');
  }
  db.execute('PRAGMA cipher_compatibility = 4');
  if (db.select('PRAGMA cipher_version').isEmpty) {
    throw StateError('this build of sqlite3 is not SQLCipher');
  }
  registerSimpleTokenizer(db);
}

// 后台 isolate 抛出的是 DriftRemoteException，toString 原样转发 SqliteException
@internal
bool isNotADatabase(Object error) {
  if (error is SqliteException) return error.extendedResultCode & 0xff == 26;
  return error.toString().startsWith('SqliteException(26)');
}

/// 明文库导出到 `.encrypting` 副本，校验后 rename 覆盖；rename 之前原文件不动，
/// 任何一步中断下次启动都从头重来。
@internal
Future<void> encryptPlaintextDatabase({
  required String path,
  required String key,
}) {
  final run = encryptImplementation;
  final afterExport = afterExportForTesting;
  return Isolate.run(() => run(path, key, afterExport: afterExport));
}

@visibleForTesting
void Function(String path, String key, {void Function(String tmp)? afterExport})
encryptImplementation = encryptDatabaseFile;

/// 在导出完成、校验之前对副本动手脚，用来测校验失败的清理路径。
@visibleForTesting
void Function(String tmp)? afterExportForTesting;

/// 失败不阻塞启动：本次按明文打开，计数退避，换版本后重试。
@internal
Future<bool> encryptPlaintextDatabaseOrSkip({
  required String path,
  required String key,
}) async {
  final failures = MoodiaryKVs.dbEncryptFailures.get() ?? 0;
  if (failures >= maxEncryptFailures) {
    logger.e(
      '数据库加密：已失败 $failures 次，本版本不再尝试',
      error: StateError('encryption backoff'),
    );
    return false;
  }
  try {
    await encryptPlaintextDatabase(path: path, key: key);
  } catch (e, s) {
    MoodiaryKVs.dbEncryptFailures.set(failures + 1);
    logger.e('数据库加密失败，本次按明文打开', error: e, stackTrace: s);
    return false;
  }
  MoodiaryKVs.dbEncryptFailures.remove();
  return true;
}

@visibleForTesting
void encryptDatabaseFile(
  String path,
  String key, {
  void Function(String tmp)? afterExport,
}) {
  final tmp = '$path$encryptingSuffix';
  final sidecars = [tmp, '$tmp-journal', '$tmp-wal', '$tmp-shm'];
  _deleteIfExists(sidecars);
  try {
    final (userVersion, counts) = _export(path, tmp, key);
    afterExport?.call(tmp);
    _verify(tmp, key, userVersion: userVersion, counts: counts);
  } catch (_) {
    _deleteIfExists(sidecars);
    rethrow;
  }
  File(tmp).renameSync(path);
  _deleteIfExists(['$path-wal', '$path-shm', '$path-journal']);
}

(int, Map<String, int>) _export(String path, String tmp, String key) {
  final source = sqlite3.open(path);
  try {
    // 先把 WAL 收进主文件并删掉，rename 之后才不会有一份明文 WAL 被套到加密库上
    final mode = source
        .select('PRAGMA journal_mode = DELETE')
        .single
        .values
        .single;
    if (mode != 'delete') throw StateError('journal_mode stayed $mode');
    final userVersion =
        source.select('PRAGMA user_version').single.values.single as int;
    final counts = _rowCounts(source);
    source.execute('PRAGMA cipher_default_compatibility = 4');
    try {
      source.execute('ATTACH DATABASE ? AS encrypted KEY ?', [tmp, "x'$key'"]);
    } on SqliteException catch (e) {
      throw StateError('ATTACH failed: ${e.extendedResultCode} ${e.message}');
    }
    source.execute("SELECT sqlcipher_export('encrypted')");
    source.execute('PRAGMA encrypted.user_version = $userVersion');
    source.execute('DETACH DATABASE encrypted');
    return (userVersion, counts);
  } finally {
    source.close();
  }
}

void _verify(
  String tmp,
  String key, {
  required int userVersion,
  required Map<String, int> counts,
}) {
  final copy = sqlite3.open(tmp);
  try {
    applyDatabaseKey(copy, key);
    final hmac = copy.select('PRAGMA cipher_integrity_check');
    if (hmac.isNotEmpty) throw StateError('cipher_integrity_check: $hmac');
    final check = copy.select('PRAGMA quick_check').single.values.single;
    if (check != 'ok') throw StateError('quick_check: $check');
    final version = copy.select('PRAGMA user_version').single.values.single;
    if (version != userVersion) {
      throw StateError('user_version $version, expected $userVersion');
    }
    final copied = _rowCounts(copy);
    for (final MapEntry(key: table, value: expected) in counts.entries) {
      if (copied[table] != expected) {
        throw StateError(
          '$table has ${copied[table]} rows, expected $expected',
        );
      }
    }
  } finally {
    copy.close();
  }
}

Map<String, int> _rowCounts(Database db) {
  final names = db
      .select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND rootpage > 0",
      )
      .map((row) => row['name'] as String);
  return {
    for (final name in names)
      name:
          db
                  .select(
                    'SELECT count(*) AS n FROM "${name.replaceAll('"', '""')}"',
                  )
                  .single['n']
              as int,
  };
}

void _deleteIfExists(List<String> paths) {
  for (final path in paths) {
    switch (FileSystemEntity.typeSync(path, followLinks: false)) {
      case FileSystemEntityType.notFound:
        break;
      case FileSystemEntityType.directory:
        Directory(path).deleteSync(recursive: true);
      case FileSystemEntityType.link:
        Link(path).deleteSync();
      default:
        File(path).deleteSync();
    }
  }
}
