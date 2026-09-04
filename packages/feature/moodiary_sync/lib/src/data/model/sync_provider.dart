import 'package:moodiary_storage/moodiary_storage.dart';

/// 后端 id 常量：既是 [SyncProviderType.value]，也是各实现类 `@Named(...)` 的实例名
/// （注解参数必须是 const，枚举字段访问不算）。两边同源，Registry 按枚举逐个取名。
abstract final class SyncProviderIds {
  static const webdav = 'webdav';
  static const s3 = 's3';
}

/// 同步后端类型枚举 —— 决定 `activateSyncProvider` 激活哪个 [IRemoteSyncBackend]。
///
/// KV 字段：[MoodiaryKVs.syncProvider]（String, default `webdav`）。
enum SyncProviderType {
  webdav(SyncProviderIds.webdav, 'WebDAV'),
  s3(SyncProviderIds.s3, 'S3 / MinIO');

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

  static void setCurrent(SyncProviderType type) =>
      MoodiaryKVs.syncProvider.set(type.value);
}
