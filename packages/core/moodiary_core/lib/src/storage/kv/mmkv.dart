import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mmkv/mmkv.dart';
import 'package:moodiary_core/src/app_logger.dart';
import 'package:moodiary_core/src/platform_service.dart';
import 'package:moodiary_core/src/storage.dart';
import 'package:moodiary_core/src/storage/kv/legacy_pref.dart';
import 'package:moodiary_core/src/values/kv.dart';
import 'package:path/path.dart';

/// `IKVStorage` 的 MMKV 实现（2.8.0 起）。相对 SharedPreferences 有三处实质差别：
///
/// - **写是同步的**：mmap + 增量 append，没有平台通道往返，所以接口不返回 Future。
/// - **「没有值」得靠 [MMKV.containsKey] 判**：`decodeBool` 一类不返回 null，
///   取不到就给 defaultValue，直接读会把「没设过」和「设成了 false」混为一谈。
/// - **没有字符串数组类型**：`List<String>` 存成 JSON 文本。
final class MmkvKVStorage extends IKVStorage {
  /// mmap 文件名。改它等于弃掉全部既有配置，别动。
  static const _mmapId = 'moodiary';

  /// mmap 文件所在目录（相对 applicationSupport）。同样是改了就丢数据。
  static const _rootDirName = 'mmkv';

  /// 「已从 SharedPreferences 搬迁过」的标记。不属于 [MoodiaryKVs]，加前缀避免撞名。
  static const _migratedKey = '__migrated_from_prefs';

  /// 本次启动旧仓库打不开、搬迁被跳过（留待下次重试）时为 true。
  /// VersionMigrator 据此**本次什么都不写**：此刻 appVersion 读出来是 null，
  /// 不守这道门会把老用户当全新安装（searchIndexBackfilled 被永久置 true）。
  static bool legacyMigrationPending = false;

  late final MMKV _mmkv;

  @override
  Future<void> init() async {
    // rootDir 显式钉在 applicationSupport：默认值是 `${Documents}/mmkv`，
    // 而 iOS 的 Documents 是用户在「文件」App 里看得见、且会进 iCloud 备份的目录。
    await MMKV.initialize(
      rootDir: join(PlatformService.get().applicationSupportPath, _rootDirName),
      // MMKV 默认 Info 档会把每次 open / 扩容都打进 logcat，release 下只留错误。
      logLevel: kDebugMode ? MMKVLogLevel.Info : MMKVLogLevel.Error,
    );
    _mmkv = MMKV(_mmapId);

    await _migrateFromPrefsOnce();

    final firstStart = get<bool>(MoodiaryKVs.firstStart.name) ?? true;
    set<bool>(MoodiaryKVs.firstStart.name, firstStart);
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
    // 标记要立刻补回来：否则「重置全部数据」之后的那次启动会重跑迁移，
    // 把旧仓库里的密码 / 同步配置又搬回来，重置就成了摆设。
    _mmkv.encodeBool(_migratedKey, true);
  }

  List<String>? _decodeStringList(String key) {
    final raw = _mmkv.decodeString(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (e, s) {
      // 存进去的一定是自己写的 JSON，解不出来说明这一格坏了；当作没有值，
      // 让调用方回退到 defaultValue，好过整条读取路径抛异常。
      logger.e('KV: $key 不是合法的字符串数组', error: e, stackTrace: s);
      return null;
    }
  }

  /// 2.8.0 一次性迁移：把 2.7.x 落在 SharedPreferences 里的配置搬进 MMKV。
  ///
  /// 只能发生在这里，不能挂进 `VersionMigrator`：判版本用的 `appVersion` 自己就存在
  /// KV 里，搬迁完成前那一格是空的，版本比对会把老用户误判成全新安装。
  ///
  /// 逐键 try/catch —— 某个键在历史版本里换过类型时 `getInt` / `getBool` 会抛
  /// TypeError，丢一格配置可以接受，卡死整轮迁移不行。旧仓库**不删**：回滚到 2.7.x
  /// 还能读到原值，代价只是密码一类多留一份，由「重置全部数据」负责清。
  Future<void> _migrateFromPrefsOnce() async {
    if (_mmkv.containsKey(_migratedKey)) return;

    final legacy = LegacyPrefsKVSource();
    try {
      await legacy.init();
    } catch (e, s) {
      // 旧仓库打不开就不置标记，下次启动再试；代价只是一次插件调用。
      // 同时亮起 pending：VersionMigrator 本次不得把 appVersion==null 当全新安装。
      legacyMigrationPending = true;
      logger.e('KV 迁移：旧仓库打不开，本次跳过', error: e, stackTrace: s);
      return;
    }

    for (final kv in MoodiaryKVs.values) {
      try {
        kv.copyFrom(legacy, into: this);
      } catch (e, s) {
        logger.e('KV 迁移：跳过 ${kv.name}', error: e, stackTrace: s);
      }
    }

    _mmkv.encodeBool(_migratedKey, true);
  }
}
