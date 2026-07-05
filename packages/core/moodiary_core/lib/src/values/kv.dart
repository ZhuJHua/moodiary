import 'package:moodiary_core/src/storage.dart';

/// Moodiary 全部本地 KV 配置；业务侧只允许通过本 enum 访问。
/// 值类型由泛型 [T] 决定；`get()` 返回 `T?`，缺值时回退 [defaultValue]。
enum MoodiaryKVs<T extends Object> {
  appVersion<String>(),
  firstStart<bool>(defaultValue: true),

  /// 自动同步总开关：开启即启用「变更后 push + 定时轮询双向 sync」（见 [AutoSyncWatcher]）。
  autoSync<bool>(defaultValue: false),
  /// 轮询间隔（秒）；过短会频繁抢占远端锁 / 读清单，徒增流量与耗电。
  syncPollInterval<int>(defaultValue: 30),
  /// 加密由 [MoodiarySecureKVs.userKey] 是否配置驱动，没有独立开关。
  syncProvider<String>(defaultValue: 'webdav'),
  webDavOption<List<String>>(),
  s3Option<List<String>>(),

  /// 同步时同时在飞的网络请求上限（push / pull 共用）；引擎读取时夹紧到合理范围。
  syncConcurrency<int>(defaultValue: 8),

  /// 本机上次同步成功完成的时间（毫秒时间戳）。0 表示从未同步。
  lastSyncTime<int>(defaultValue: 0),

  /// 每条 `deleted=true` 日记被哪些云后端推过 tombstone，JSON 形式 `{"<diaryId>": [...]}`。
  /// 集合覆盖「当前所有已配置云后端」后引擎才从 Isar 真正清除。
  tombstonePushedBackends<String>(defaultValue: '{}'),

  /// 本机在远端同步锁（`sync.lock`）中的身份标识。首次生成随机 UUID 后保持不变，
  /// 重启 / 崩溃后能识别并接管自己残留的锁。
  syncDeviceId<String>(defaultValue: ''),

  color<int>(),
  colorType<int>(defaultValue: 0 /* AppColorType.common.value */),
  themeMode<int>(defaultValue: 0),
  dynamicColor<bool>(defaultValue: true),
  fontTheme<int>(defaultValue: 0),
  fontScale<double>(defaultValue: 1.0),
  customFont<String>(defaultValue: ''),

  quality<int>(defaultValue: 2),
  homeViewMode<int>(defaultValue: 1 /* ViewModeType.grid.number */),
  homeSortMode<int>(defaultValue: 0 /* DiarySort.timeDesc.number */),

  categoryOrder<List<String>>(),

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
  userKey;

  Future<String?> get() => ISecureKVStorage.get().get(name);

  Future<void> set(String value) => ISecureKVStorage.get().set(name, value);

  Future<void> remove() => ISecureKVStorage.get().remove(name);
}
