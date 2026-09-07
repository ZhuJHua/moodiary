import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class LegacyPrefsKVSource implements IKVSource {
  static Set<String> get _legacyKeys => {
    ...SecretKVMigration.movedKeys,
    'lock',
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

  static Future<void> clearStore() =>
      SharedPreferencesAsync().clear(allowList: _allKeys);
}
