import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

enum MoodiaryKVs<T extends Object> {
  appVersion<String>(),
  firstStart<bool>(defaultValue: true),

  searchIndexBackfilled<bool>(defaultValue: false),

  dbEngineMigrated<bool>(defaultValue: false),

  contentSchemaV2<bool>(defaultValue: false),

  autoSync<bool>(defaultValue: false),

  syncPollInterval<int>(defaultValue: 30),

  syncProvider<String>(defaultValue: 'webdav'),

  syncConcurrency<int>(defaultValue: 8),

  lastSyncTime<int>(defaultValue: 0),

  syncManifestStat<String>(defaultValue: ''),

  syncPendingLocal<bool>(defaultValue: true),

  syncKeyfileCache<String>(defaultValue: ''),

  syncKeyfilePendingBackends<List<String>>(),

  syncKeyConflictBackends<List<String>>(),

  syncForceMediaReuploadBackends<List<String>>(),

  syncDeviceId<String>(defaultValue: ''),

  lanSendTarget<String>(defaultValue: ''),

  themeAccentMode<int>(defaultValue: 0),

  themeAccentColor<int>(defaultValue: 0xFF2E59A7),

  moodPalette<String>(defaultValue: 'classic'),

  pendingMoodNotice<bool>(defaultValue: false),

  themeMode<int>(defaultValue: 0),

  fontTheme<int>(defaultValue: 0),

  customFont<String>(defaultValue: ''),

  homeViewMode<int>(defaultValue: 3 /* ViewModeType.timeline.number */),
  homeSortMode<int>(defaultValue: 0 /* DiarySort.timeDesc.number */),

  categoryOrder<List<String>>(),

  exportSettings<String>(defaultValue: ''),

  searchHistory<List<String>>(),
  firstLineIndent<bool>(defaultValue: false),
  showWritingTime<bool>(defaultValue: true),
  showWordCount<bool>(defaultValue: true),

  editorImeHeightPortrait<double>(defaultValue: 0),
  editorImeHeightLandscape<double>(defaultValue: 0),
  editorToolbarOrder<List<String>>(),
  editorToolbarHidden<List<String>>(),

  lockNow<bool>(defaultValue: false),

  appLockHint<bool>(),
  appLockFailCount<int>(defaultValue: 0),
  appLockLockedUntil<int>(defaultValue: 0),
  supportBiometrics<bool>(defaultValue: false),
  backendPrivacy<bool>(defaultValue: false),

  qweatherApiHost<String>(),

  assistantActiveProviderId<String>(defaultValue: ''),

  assistantDisclaimerAccepted<bool>(defaultValue: false),

  assistantReasoningEffort<String>(),

  assistantLastProviderId<String>(defaultValue: ''),

  assistantLastModelId<String>(defaultValue: ''),

  assistantPermissionMode<String>(defaultValue: 'confirm'),

  assistantUserNotes<String>(defaultValue: ''),

  assistantMemoryEnabled<bool>(defaultValue: true),

  llmPresetCache<String>(defaultValue: ''),

  llmPresetCacheAt<int>(defaultValue: 0),

  embeddingModelId<String>(defaultValue: ''),

  embeddingDim<int>(defaultValue: 0),

  embeddingIndexStale<bool>(defaultValue: false),

  modelDownloadEndpoint<String>(defaultValue: ''),

  getWeather<bool>(defaultValue: false),

  autoWeather<bool>(defaultValue: false),

  autoPosition<bool>(defaultValue: false),

  autoNearestPlace<bool>(defaultValue: false),

  placeOrder<List<String>>(),

  /// 词云的屏蔽词（用户自己维护，只在本机）。默认停用词是代码常量，不走这里。
  wordCloudBlockedWords<List<String>>(),

  /// 词云的自定义词典：按整词统计，用来修正 jieba 的分词（「存在性需求」）。
  /// 词典优先于内置停用词表 —— 它同时也是一份「保留名单」。
  wordCloudLexicon<List<String>>(),

  /// 词云是否隐藏单个字（中英文都一样）。默认关：先靠扩容后的停用词表。
  wordCloudHideSingleChars<bool>(defaultValue: false),

  mapTileSource<String>(defaultValue: ''),

  weather<List<String>>(),

  supportPath<String>(),
  cachePath<String>(),
  uuid<String>(),
  local<bool>(defaultValue: false),
  language<String>(defaultValue: 'system');

  final T? defaultValue;

  const MoodiaryKVs({this.defaultValue});

  T? get() => getIt<IKVStorage>().get<T>(name) ?? defaultValue;

  void set(T value) => getIt<IKVStorage>().set<T>(name, value);

  void remove() => getIt<IKVStorage>().remove(name);

  void copyFrom(IKVSource source, {required IKVStorage into}) {
    final value = source.get<T>(name);
    if (value != null) into.set<T>(name, value);
  }

  KVNotifier<T> getNotifier() {
    if (defaultValue == null) {
      throw StateError(
        'MoodiaryKVs.$name has no defaultValue; getNotifier() requires one.',
      );
    }
    return getIt<IKVStorage>().getNotifier<T>(name, defaultValue as T);
  }

  KVNotifier<T> getNotifierOr(T fallback) {
    return getIt<IKVStorage>().getNotifier<T>(name, defaultValue ?? fallback);
  }
}

enum MoodiarySecureKVs {
  syncDek,

  webDavOption,

  s3Option,

  // 别直接读写这个键，走 AppLockPin —— 直接 set(pin) 会静默存进明文
  password,

  qweatherKey,

  tiandituKey;

  Future<String?> get() => getIt<ISecureKVStorage>().get(name);

  Future<void> set(String value) => getIt<ISecureKVStorage>().set(name, value);

  Future<void> remove() => getIt<ISecureKVStorage>().remove(name);
}
