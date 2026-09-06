import 'package:moodiary_storage/moodiary_storage.dart';

abstract final class SyncProviderIds {
  static const webdav = 'webdav';
  static const s3 = 's3';
}

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
