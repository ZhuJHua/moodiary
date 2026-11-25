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
}
