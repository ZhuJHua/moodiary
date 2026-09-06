import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

enum MoodiaryKVs<T extends Object> {
  appVersion<String>(),
  firstStart<bool>(defaultValue: true),

  searchIndexBackfilled<bool>(defaultValue: false),

  dbEngineMigrated<bool>(defaultValue: false),

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

  lockNow<bool>(defaultValue: false),

  appLockHint<bool>(),
  supportBiometrics<bool>(defaultValue: false),
  backendPrivacy<bool>(defaultValue: false),

  qweatherApiHost<String>(),

  assistantActiveProviderId<String>(defaultValue: ''),

  assistantDisclaimerAccepted<bool>(defaultValue: false),

  assistantReasoningEffort<String>(defaultValue: ''),

  assistantAgentPresetId<String>(defaultValue: ''),

  llmPresetCache<String>(defaultValue: ''),

  llmPresetCacheAt<int>(defaultValue: 0),

  embeddingModelId<String>(defaultValue: ''),

  embeddingDim<int>(defaultValue: 0),

  embeddingIndexStale<bool>(defaultValue: false),

  modelDownloadMirror<bool>(defaultValue: true),

  moodLlmModelId<String>(defaultValue: ''),

  getWeather<bool>(defaultValue: false),

  autoWeather<bool>(defaultValue: false),

  autoPosition<bool>(defaultValue: false),

  autoNearestPlace<bool>(defaultValue: false),

  placeOrder<List<String>>(),
  weather<List<String>>(),

  startTime<int>(),
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
