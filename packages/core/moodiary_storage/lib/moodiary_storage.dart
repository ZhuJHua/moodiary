/// 存储层：KV（MMKV）、SecureKV（钥匙串）、Isar 数据库句柄。
///
/// 刻意**不认识文件布局，也不认识领域类型**：Isar 的目录与 schema 列表都由组合根
/// 注入。这两条注入就是本包能待在 moodiary_files 之下的原因。
library;

export 'src/exception.dart';
export 'src/isar.dart';
export 'src/kv/app_lock_pin.dart';
export 'src/kv/legacy_pref.dart';
export 'src/kv/mmkv.dart';
export 'src/kv/secret_migration.dart';
export 'src/kv/secure.dart';
export 'src/kv_keys.dart';
export 'src/storage.dart';
