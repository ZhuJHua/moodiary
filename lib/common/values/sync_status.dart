/// 同步状态枚举
enum SyncStatus {
  /// 已分配任务但还未执行
  pending,

  /// 正在同步中
  syncing,

  /// 同步成功
  success,

  /// 同步失败
  failure,

  /// 验证失败
  invalid,

  /// 未知状态
  unknown,
}

/// 连接状态枚举
enum ConnectivityStatus {
  /// 未连接
  disconnected,

  /// 正在连接
  connecting,

  /// 已连接
  connected,
}
