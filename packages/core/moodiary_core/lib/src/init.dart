import 'package:moodiary_core/src/di.dart';
import 'package:moodiary_core/src/platform_service.dart';
import 'package:moodiary_core/src/storage.dart';
import 'package:moodiary_core/src/storage/database/isar.dart';
import 'package:moodiary_core/src/storage/kv/pref.dart';
import 'package:moodiary_core/src/storage/kv/secure.dart';
import 'package:moodiary_core/src/utils/file_util.dart';

/// 基础设施层一次性初始化入口。
///
/// 路径 + 业务目录是后续存储的前置（Isar 要求 database 目录存在；KV.init 经
/// MergeUtil 读 applicationSupportPath），故先串行就位，再并发三条独立存储。
/// 不在此调用 RustLib.init / ThemeUtil / registerService——那些含业务/UI 决策，
/// 由 main.dart 显式调用以便启动期定制。
Future<void> injectBasicService() async {
  getIt.registerSingleton<IKVStorage>(SharedPreferencesKVStorage());
  getIt.registerSingleton<ISecureKVStorage>(FlutterSecureStorageKVStorage());

  await PlatformService.get().init();
  await FileUtil.initCreateDir();

  await Future.wait([
    IKVStorage.get().init(),
    ISecureKVStorage.get().init(),
    IsarDatabase.get().init(),
  ]);
}

/// 重置所有应用数据，恢复到「全新安装」状态（Isar 集合 / KV / SecureKV / 媒体 / 缓存）。
/// 返回后内存仍残留 Riverpod / get_it 单例状态，调用方必须紧接着退出应用，
/// 由下次启动重走 [injectBasicService] 从干净存储初始化。
Future<void> resetAllData() async {
  // 先清空数据库集合（保持 Isar 句柄有效），再并发清空其余存储与文件。
  await IsarDatabase.get().clear();
  await Future.wait([
    IKVStorage.get().clear(),
    ISecureKVStorage.get().clear(),
    FileUtil.resetUserMediaDirs(),
    FileUtil.clearCache(),
  ]);
}
