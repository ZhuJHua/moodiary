import 'package:moodiary_core/src/storage.dart';
import 'package:moodiary_core/src/values/kv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2.8.0 之前的 KV 后端。现在只剩两个用途：给 [MmkvKVStorage] 的一次性迁移当**只读**
/// 数据源，以及「重置全部数据」时把旧仓库一并清掉。迁移窗口过后连同
/// `shared_preferences` 依赖一起删除。
///
/// 读的是 `SharedPreferencesAsync` 那套后端（Android DataStore / iOS NSUserDefaults，
/// 键无前缀）——2.7.3 线上写入的就是它，不是 legacy API 那个带 `flutter.` 前缀的
/// XML 仓库，两者互不相通。
final class LegacyPrefsKVSource implements IKVSource {
  static Set<String> get _ownKeys =>
      MoodiaryKVs.values.map((e) => e.name).toSet();

  /// 2.7.3 写过、HEAD 枚举里已不存在的敏感键：WebDAV 凭据（明文 `[url, user, password]`）
  /// 与腾讯地图 key。它们不迁移（同步引擎已重写），但清理名单必须带上——只按 HEAD 键名
  /// 清会把这份明文密码永久留在旧仓库里。
  static const Set<String> _legacySensitiveKeys = {
    'webDavOption',
    'tencentId',
    'tencentKey',
  };

  late final SharedPreferencesWithCache _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(allowList: _ownKeys),
    );
  }

  @override
  T? get<T extends Object>(String key) => switch (T) {
    const (int) => _prefs.getInt(key) as T?,
    const (bool) => _prefs.getBool(key) as T?,
    const (double) => _prefs.getDouble(key) as T?,
    const (String) => _prefs.getString(key) as T?,
    const (List<String>) => _prefs.getStringList(key) as T?,
    _ => throw ArgumentError('Unsupported type: $T'),
  };

  /// 清掉旧仓库里属于本 App 的键。「重置全部数据」要调：迁移是复制而非搬移，
  /// 密码 / API key 这类值搬进 MMKV 后旧仓库里还留着一份，不清就绕过了重置。
  ///
  /// **allowList 必须显式给**：不传时 iOS 侧遍历的是 `dictionaryRepresentation()`，
  /// 那里面混着 NSGlobalDomain（AppleLanguages、键盘设置…）和别的插件写的键，
  /// 一句 `clear()` 会把它们一并删掉。
  static Future<void> clearStore() => SharedPreferencesAsync().clear(
    allowList: {..._ownKeys, ..._legacySensitiveKeys},
  );
}
