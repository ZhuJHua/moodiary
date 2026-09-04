import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PlatformService {
  static final PlatformService _instance = ._internal();

  factory PlatformService.get() => _instance;

  PlatformService._internal();

  late final Directory applicationSupportDirectory;

  late final String applicationSupportPath;

  late final Directory applicationCacheDirectory;

  late final String applicationCachePath;

  /// 只做路径。生物识别探测**不在这里**：`canCheckBiometrics` 是一次 BiometricManager
  /// 的 binder 调用，真机冷启动实测 26–48ms，曾占掉整个 bootstrapPlatform；锁页与
  /// 设置项用到时自己调 `BiometricAuth.canCheckBiometrics()`。
  Future<void> init() async {
    final (supportDir, cacheDir) = await (
      getApplicationSupportDirectory(),
      getApplicationCacheDirectory(),
    ).wait;

    applicationSupportDirectory = supportDir;
    applicationSupportPath = supportDir.path;
    applicationCacheDirectory = cacheDir;
    applicationCachePath = cacheDir.path;
  }
}
