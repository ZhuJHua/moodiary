import 'package:moodiary_core/src/values/kv.dart';
import 'package:moodiary_core/src/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `IKVStorage` 的 SharedPreferences 实现。[init] 落 `firstStart` 标记。版本迁移钩子
/// （`VersionMigrator`）已上移到组合根（`main.dart`）调用，以解除 core → merge 反向依赖。
final class SharedPreferencesKVStorage extends IKVStorage {
  late final SharedPreferencesWithCache _prefs;

  @override
  Future<void> clear() async {
    await _prefs.clear();
  }

  @override
  T? get<T extends Object>(String key) {
    if (T == int) {
      return _prefs.getInt(key) as T?;
    } else if (T == bool) {
      return _prefs.getBool(key) as T?;
    } else if (T == double) {
      return _prefs.getDouble(key) as T?;
    } else if (T == String) {
      return _prefs.getString(key) as T?;
    } else if (T == List<String>) {
      return _prefs.getStringList(key) as T?;
    } else {
      throw ArgumentError('Unsupported type: $T');
    }
  }

  @override
  Future<void> init() async {
    _prefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(
        allowList: MoodiaryKVs.values.map((e) => e.name).toSet(),
      ),
    );

    final firstStart = _prefs.getBool(MoodiaryKVs.firstStart.name) ?? true;
    await _prefs.setBool(MoodiaryKVs.firstStart.name, firstStart);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
    await super.remove(key);
  }

  @override
  Future<void> set<T extends Object>(String key, T value) async {
    if (T == int) {
      await _prefs.setInt(key, value as int);
    } else if (T == bool) {
      await _prefs.setBool(key, value as bool);
    } else if (T == double) {
      await _prefs.setDouble(key, value as double);
    } else if (T == String) {
      await _prefs.setString(key, value as String);
    } else if (T == List<String>) {
      await _prefs.setStringList(key, value as List<String>);
    } else {
      throw ArgumentError('Unsupported type: $T');
    }
    await super.set(key, value);
  }
}
