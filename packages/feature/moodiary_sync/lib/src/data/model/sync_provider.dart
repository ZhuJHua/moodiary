import 'package:moodiary_core/moodiary_core.dart';

/// 同步后端类型枚举 —— 决定 DI 中注入哪个 [IRemoteSyncBackend]。
///
/// KV 字段：[MoodiaryKVs.syncProvider]（String, default `webdav`）。
enum SyncProviderType {
  webdav('webdav', 'WebDAV'),
  s3('s3', 'S3 / MinIO');

  final String value;
  final String label;

  const SyncProviderType(this.value, this.label);

  static SyncProviderType fromValue(String? v) {
    return values.firstWhere(
      (e) => e.value == v,
      orElse: () => SyncProviderType.webdav,
    );
  }

  static SyncProviderType current() =>
      fromValue(MoodiaryKVs.syncProvider.get());

  static Future<void> setCurrent(SyncProviderType type) =>
      MoodiaryKVs.syncProvider.set(type.value);
}
