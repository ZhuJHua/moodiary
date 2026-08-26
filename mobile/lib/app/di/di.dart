import 'package:injectable/injectable.dart';
import 'package:moodiary/app/di/di.config.dart';
import 'package:moodiary_assistant/injectable.module.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_http/injectable.module.dart';
import 'package:moodiary_storage/injectable.module.dart';
import 'package:moodiary_sync/injectable.module.dart';

/// 容器装配的唯一入口：没有 initializerName（用默认的 `init`），也没有
/// generateForDir（默认扫全包）—— 只有一份 config，不存在「两份扫同一片源码、
/// 同一注解被各注册一次」的互斥问题，白名单也就不必要了。
///
/// 四个包各自是一份 micro-package（`@InjectableInit.microPackage()` 生成
/// `injectable.module.dart`），在这里经 externalPackageModulesBefore 挂载。
/// **storage 列最前**：它的两个 preResolve 绑定（SecureKV → KV）是别人的地基。
///
/// 容器只管生命周期内不变的接线。「什么时候按 KV 装载同步后端、什么时候唤醒
/// 长驻服务」是启动编排，归 main.dart，不归容器。
@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(MoodiaryStoragePackageModule),
    ExternalModule(MoodiaryHttpPackageModule),
    ExternalModule(MoodiaryAssistantPackageModule),
    ExternalModule(MoodiarySyncPackageModule),
  ],
  preferRelativeImports: false,
)
Future<void> configureDependencies() async => getIt.init();
