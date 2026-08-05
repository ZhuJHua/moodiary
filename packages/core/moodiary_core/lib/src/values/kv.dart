import 'package:moodiary_core/src/storage.dart';

/// Moodiary 全部本地 KV 配置；业务侧只允许通过本 enum 访问。
/// 值类型由泛型 [T] 决定；`get()` 返回 `T?`，缺值时回退 [defaultValue]。
enum MoodiaryKVs<T extends Object> {
  appVersion<String>(),
  firstStart<bool>(defaultValue: true),

  /// 升级/首启后是否已一次性回填全量搜索 + 双链倒排索引。旧库从未建过倒排索引，若不回填
  /// 则所有既有日记正文搜不到、双链为空；回填一次后置位，之后靠增量索引维护。
  searchIndexBackfilled<bool>(defaultValue: false),

  /// 自动同步总开关：开启即启用「变更后 push + 定时轮询双向 sync」（见 [AutoSyncWatcher]）。
  autoSync<bool>(defaultValue: false),

  /// 轮询间隔（秒）；过短会频繁抢占远端锁 / 读清单，徒增流量与耗电。
  syncPollInterval<int>(defaultValue: 30),

  /// 加密由 [MoodiarySecureKVs.syncDek] 是否配置驱动，没有独立开关。
  syncProvider<String>(defaultValue: 'webdav'),

  /// 同步时同时在飞的网络请求上限（push / pull 共用）；引擎读取时夹紧到合理范围。
  syncConcurrency<int>(defaultValue: 8),

  /// 本机上次同步成功完成的时间（毫秒时间戳）。0 表示从未同步。
  lastSyncTime<int>(defaultValue: 0),

  /// 上次成功 syncAll 前观测到的远端 manifest 指纹（`<backendId>|<Last-Modified>`）。
  /// 轮询 HEAD 比对命中且本地无待推变更时跳过整个同步（空转短路）。
  syncManifestStat<String>(defaultValue: ''),

  /// 自上次成功同步后本地是否有待推变更（含分类 / 删除；云 pull 落库的不算）。
  /// 缺省 true（保守：未知即视作有变更，走完整同步）。
  syncPendingLocal<bool>(defaultValue: true),

  /// 最近一次读到 / 写出的远端 keys.json 原文（明文 JSON，非机密——内容只有
  /// 盐、KDF 参数和没有密码解不开的密文）。供密钥管理页离线校验当前密码，
  /// 以及向尚未送达的后端补传（见 syncKeyfilePendingBackends）。
  syncKeyfileCache<String>(defaultValue: ''),

  /// keyfile 待上传的后端 id 清单：开启加密 / 改密码时写远端失败（或后端离线 /
  /// 后配）的后端记在这里，该后端下次同步由引擎前奏补传缓存的 keyfile。
  syncKeyfilePendingBackends<List<String>>(),

  /// 本机在远端同步锁（`sync.lock`）中的身份标识。首次生成随机 UUID 后保持不变，
  /// 重启 / 崩溃后能识别并接管自己残留的锁。
  syncDeviceId<String>(defaultValue: ''),

  /// 局域网发送页上次输入的目标地址（`ip` 或 `ip:端口`），便于重复发送。
  lanSendTarget<String>(defaultValue: ''),

  color<int>(),
  colorType<int>(defaultValue: 0 /* AppColorType.common.value */),
  themeMode<int>(defaultValue: 0),
  dynamicColor<bool>(defaultValue: true),
  fontTheme<int>(defaultValue: 0),
  fontScale<double>(defaultValue: 1.0),
  customFont<String>(defaultValue: ''),

  /// 图片优化：存储时按 1280 规则压缩 + 统一转 WebP；关闭则保存原图（HEIC 仍转码）。
  imageOptimize<bool>(defaultValue: true),
  homeViewMode<int>(defaultValue: 3 /* ViewModeType.timeline.number */),
  homeSortMode<int>(defaultValue: 0 /* DiarySort.timeDesc.number */),

  categoryOrder<List<String>>(),

  /// 导出配置（JSON，见 moodiary_export 的 ExportSettings）。按格式分别记，
  /// 下次进导出页沿用上次的选择。
  exportSettings<String>(defaultValue: ''),

  /// 日记搜索历史（最近在前、去重、截断到上限）。
  searchHistory<List<String>>(),
  diaryHeader<bool>(defaultValue: true),
  firstLineIndent<bool>(defaultValue: false),
  autoCategory<bool>(defaultValue: false),
  showWritingTime<bool>(defaultValue: true),
  showWordCount<bool>(defaultValue: true),

  lock<bool>(defaultValue: false),
  lockNow<bool>(defaultValue: false),
  password<String>(),
  supportBiometrics<bool>(defaultValue: false),
  backendPrivacy<bool>(defaultValue: false),

  qweatherKey<String>(),
  qweatherApiHost<String>(),
  tiandituKey<String>(),

  /// 当前激活的 Provider id（对应 `LlmProvider.id`）。空表示未选 / 回退列表首个。
  assistantActiveProviderId<String>(defaultValue: ''),

  /// 用户是否已同意 AI 助手免责声明。未同意前助手不可用。
  assistantDisclaimerAccepted<bool>(defaultValue: false),

  /// 已被用户「始终允许」的助手工具 id 列表，命中后不再弹权限框。
  assistantAlwaysAllowedTools<List<String>>(),

  /// 新建 AI 会话的默认思考（reasoning）模式；每个会话的实际开关存于 ChatSession.thinking。
  assistantThinkingEnabled<bool>(defaultValue: false),

  /// 远端预定义供应商的原始 JSON 缓存（moodiary-llm-provider/index.json）。
  llmPresetCache<String>(defaultValue: ''),

  llmPresetCacheAt<int>(defaultValue: 0),

  getWeather<bool>(defaultValue: false),
  autoWeather<bool>(defaultValue: false),
  weather<List<String>>(),

  startTime<int>(),
  supportPath<String>(),
  cachePath<String>(),
  uuid<String>(),
  local<bool>(defaultValue: false),
  language<String>(defaultValue: 'system');

  final T? defaultValue;

  const MoodiaryKVs({this.defaultValue});

  T? get() => IKVStorage.get().get<T>(name) ?? defaultValue;

  Future<void> set(T value) async {
    await IKVStorage.get().set<T>(name, value);
  }

  Future<void> remove() async {
    await IKVStorage.get().remove(name);
  }

  KVNotifier<T> getNotifier() {
    if (defaultValue == null) {
      throw StateError(
        'MoodiaryKVs.$name has no defaultValue; getNotifier() requires one.',
      );
    }
    return IKVStorage.get().getNotifier<T>(name, defaultValue as T);
  }

  /// 同 [getNotifier]，但就地提供 [fallback]，用于无 defaultValue 又想监听的 key。
  KVNotifier<T> getNotifierOr(T fallback) {
    return IKVStorage.get().getNotifier<T>(name, defaultValue ?? fallback);
  }
}

enum MoodiarySecureKVs {
  /// 同步数据密钥 DEK（base64 的 32 字节随机 key）。所有同步对象用它做
  /// AES-256-GCM；用户密码只用于解包远端 keys.json 里包着的这把 key，
  /// 密码原文不落本机。
  syncDek,

  /// WebDAV 连接配置，JSON 数组 `[baseUrl, username, password]`。含密码，故进 SecureKV。
  webDavOption,

  /// S3 连接配置，JSON 数组，索引见 `S3SyncBackend`。含 secretKey，故进 SecureKV。
  s3Option;

  Future<String?> get() => ISecureKVStorage.get().get(name);

  Future<void> set(String value) => ISecureKVStorage.get().set(name, value);

  Future<void> remove() => ISecureKVStorage.get().remove(name);
}
