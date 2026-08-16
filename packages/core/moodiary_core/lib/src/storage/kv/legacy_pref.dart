import 'package:moodiary_core/src/storage.dart';
import 'package:moodiary_core/src/storage/kv/secret_migration.dart';
import 'package:moodiary_core/src/values/kv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2.8.0 之前的 KV 后端，现在只是那一次性搬迁的**只读**数据源（明文键进 MMKV、
/// 三个机密进 SecureKV），搬完当场由 [clearStore] 整个清掉。
/// `shared_preferences` 依赖只为这次搬迁留着，窗口过后连同本文件一起删除。
///
/// 读的是 `SharedPreferencesAsync` 那套后端（Android DataStore / iOS NSUserDefaults，
/// 键无前缀）——2.7.3 线上写入的就是它，不是 legacy API 那个带 `flutter.` 前缀的
/// XML 仓库，两者互不相通。
final class LegacyPrefsKVSource implements IKVSource {
  /// 2.7.3 写过、但 HEAD 的 [MoodiaryKVs] 里已经没有的键。
  ///
  /// **这里只能是字面量**：它们记录的是过去的形状，代码里已经没有对应的符号了。
  /// 别改成从 [MoodiarySecureKVs] 之类的**当前**枚举推导——那只是"旧名字碰巧等于
  /// 新名字"，谁给枚举改个名，这里就静默地少读一个键、少清一个键，不报错。
  ///
  /// 要搬走的那三个直接取 [SecretKVMigration.movedKeys]（同样是迁移侧的字面量），
  /// 让「搬迁读的键必然在 allowList 里」由构造成立，而不是靠一条测试去断言。
  static Set<String> get _legacyKeys => {
    ...SecretKVMigration.movedKeys,
    // 不迁移（同步引擎已重写 / 已换供应商），但清理时必须带上：都含明文凭据
    'webDavOption',
    'tencentId',
    'tencentKey',
  };

  static Set<String> get _allKeys => {
    ...MoodiaryKVs.values.map((e) => e.name),
    ..._legacyKeys,
  };

  late final SharedPreferencesWithCache _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(allowList: _allKeys),
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

  /// 清掉旧仓库里属于本 App 的键。搬迁的最后一步调它 —— 那里躺着明文 PIN /
  /// API Key / WebDAV 密码，留着就是留一份副本进系统备份。「重置全部数据」也调：
  /// 重置若发生在搬迁完成之前，旧仓库还在，不清就会被下次启动的搬迁原样搬回来。
  ///
  /// **allowList 必须显式给。** 不传时插件走的是 `dictionaryRepresentation()` 的合并
  /// 视图逐键 `removeObject`（见 shared_preferences_foundation 的
  /// `SharedPreferencesPlugin.clear`，同文件的 `getAllPrefs` 反倒老实用了
  /// `persistentDomain(forName:)`）。全局域的键删不动是空转，但**同一个 App 里其他
  /// 插件写的键就在 app 域，是真删** —— 相册选择器一类的偏好会一起没。
  static Future<void> clearStore() =>
      SharedPreferencesAsync().clear(allowList: _allKeys);
}
