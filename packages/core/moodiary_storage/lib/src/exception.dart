// 注：同步层有自己的 `SyncException`（moodiary_sync src/data/sync.dart），故此处不再定义，
// 避免随 barrel 导出产生重名歧义。本文件只保留 core 通用异常。
class DatabaseException implements Exception {
  final String message;

  DatabaseException(this.message);

  @override
  String toString() {
    return 'DatabaseException: $message';
  }
}
