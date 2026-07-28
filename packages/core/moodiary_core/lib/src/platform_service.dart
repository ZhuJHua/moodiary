import 'dart:io';

import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path_provider/path_provider.dart';

class PlatformService {
  static final PlatformService _instance = PlatformService._internal();

  factory PlatformService.get() => _instance;

  PlatformService._internal();

  late final Directory applicationSupportDirectory;

  late final String applicationSupportPath;

  late final Directory applicationCacheDirectory;

  late final String applicationCachePath;

  late final bool supportBiometrics;

  Future<void> init() async {
    final (supportDir, cacheDir, canBio) = await (
      getApplicationSupportDirectory(),
      getApplicationCacheDirectory(),
      BiometricAuth.canCheckBiometrics(),
    ).wait;

    applicationSupportDirectory = supportDir;
    applicationSupportPath = supportDir.path;
    applicationCacheDirectory = cacheDir;
    applicationCachePath = cacheDir.path;
    supportBiometrics = canBio;
  }
}
