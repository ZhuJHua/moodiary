import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:mmkv/mmkv.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:path/path.dart';

@Singleton(as: IKVStorage)
final class MmkvKVStorage extends IKVStorage {
  // 改这个值等于丢弃全部现有配置
  static const _mmapId = 'moodiary';

  // 改这个目录同样会丢数据
  static const _rootDirName = 'mmkv';

  static const _migratedKey = '__migrated_from_prefs';

  static bool legacyMigrationPending = false;

  late final MMKV _mmkv;

  // secure 只用于让 DI 保证 SecureKV 先于本类构造，函数体内不使用
  @FactoryMethod(preResolve: true)
  static Future<MmkvKVStorage> create(ISecureKVStorage secure) async {
    final storage = MmkvKVStorage();
    await storage.init();
    return storage;
  }

  @override
  Future<void> init() async {
    await MMKV.initialize(
      rootDir: join(PlatformService.get().applicationSupportPath, _rootDirName),
      logLevel: kDebugMode ? MMKVLogLevel.Info : MMKVLogLevel.Error,
    );
    _mmkv = MMKV(_mmapId);

    await _migrateFromPrefsOnce();

    if (!legacyMigrationPending) {
      final firstStart = get<bool>(MoodiaryKVs.firstStart.name) ?? true;
      set<bool>(MoodiaryKVs.firstStart.name, firstStart);
    }
  }

  @override
  T? get<T extends Object>(String key) {
    if (!_mmkv.containsKey(key)) return null;
    return switch (T) {
      const (int) => _mmkv.decodeInt(key) as T?,
      const (bool) => _mmkv.decodeBool(key) as T?,
      const (double) => _mmkv.decodeDouble(key) as T?,
      const (String) => _mmkv.decodeString(key) as T?,
      const (List<String>) => _decodeStringList(key) as T?,
      _ => throw ArgumentError('Unsupported type: $T'),
    };
  }

  @override
  void set<T extends Object>(String key, T value) {
    switch (T) {
      case const (int):
        _mmkv.encodeInt(key, value as int);
      case const (bool):
        _mmkv.encodeBool(key, value as bool);
      case const (double):
        _mmkv.encodeDouble(key, value as double);
      case const (String):
        _mmkv.encodeString(key, value as String);
      case const (List<String>):
        _mmkv.encodeString(key, jsonEncode(value));
      default:
        throw ArgumentError('Unsupported type: $T');
    }
    super.set(key, value);
  }

  @override
  void remove(String key) {
    _mmkv.removeValue(key);
    super.remove(key);
  }

  @override
  void clear() {
    _mmkv.clearAll();
    _mmkv.encodeBool(_migratedKey, true);
  }

  List<String>? _decodeStringList(String key) {
    final raw = _mmkv.decodeString(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (e, s) {
      logger.e('KV: $key 不是合法的字符串数组', error: e, stackTrace: s);
      return null;
    }
  }

  Future<void> _migrateFromPrefsOnce() async {
    if (_mmkv.containsKey(_migratedKey)) return;

    final legacy = LegacyPrefsKVSource();
    try {
      await legacy.init();
    } catch (e, s) {
      legacyMigrationPending = true;
      logger.e('KV 迁移：旧仓库打不开，本次跳过', error: e, stackTrace: s);
      return;
    }

    try {
      await SecretKVMigration.run(legacy);
    } catch (e, s) {
      legacyMigrationPending = true;
      logger.e('KV 迁移：机密搬迁失败，本次整轮跳过', error: e, stackTrace: s);
      return;
    }

    for (final kv in MoodiaryKVs.values) {
      try {
        kv.copyFrom(legacy, into: this);
      } catch (e, s) {
        logger.e('KV 迁移：跳过 ${kv.name}', error: e, stackTrace: s);
      }
    }

    try {
      await LegacyPrefsKVSource.clearStore();
    } catch (e, s) {
      logger.e('KV 迁移：旧仓库清理失败，值已搬完照常放行', error: e, stackTrace: s);
    }
    _mmkv.encodeBool(_migratedKey, true);
  }
}
