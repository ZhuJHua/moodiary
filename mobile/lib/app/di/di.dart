import 'package:injectable/injectable.dart';
import 'package:moodiary_assistant/injectable.module.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart'
    show AssistantService;
import 'package:moodiary_data/injectable.module.dart';
import 'package:moodiary_data/moodiary_data.dart'
    show IBackupArchive, MoodiaryDatabase;
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/injectable.module.dart';
import 'package:moodiary_files/moodiary_files.dart'
    show IFilePicker, IHeifDecoder;
import 'package:moodiary_http/injectable.module.dart';
import 'package:moodiary_http/moodiary_http.dart' show IHttpClient, IHttpServer;
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_ml/injectable.module.dart';
import 'package:moodiary_mobile/app/di/di.config.dart';
import 'package:moodiary_storage/injectable.module.dart';
import 'package:moodiary_storage/moodiary_storage.dart'
    show IKVStorage, ISecureKVStorage;
import 'package:moodiary_sync/injectable.module.dart';
import 'package:moodiary_sync/moodiary_sync.dart'
    show AutoSyncWatcher, IRemoteSyncBackend, SyncLogger, SyncProviderType;

/// 容器装配的唯一入口：没有 initializerName（用默认的 `init`），也没有
/// generateForDir（默认扫全包）—— 只有一份 config，不存在「两份扫同一片源码、
/// 同一注解被各注册一次」的互斥问题，白名单也就不必要了。
///
/// 六个包各自是一份 micro-package（`@InjectableInit.microPackage()` 生成
/// `injectable.module.dart`），在这里经 externalPackageModulesBefore 挂载。
/// **storage 列最前**：它的两个 preResolve 绑定（SecureKV → KV）是别人的地基。
///
/// 容器只管生命周期内不变的接线。「什么时候按 KV 装载同步后端、什么时候唤醒
/// 长驻服务」是启动编排，归 main.dart，不归容器。
@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(MoodiaryStoragePackageModule),
    ExternalModule(MoodiaryHttpPackageModule),
    // ml 在 http 之后：EmbeddingModelManager 注入 IHttpClient 下载模型。
    ExternalModule(MoodiaryMlPackageModule),
    // data 的仓储都是懒单例，依赖本 config 的 AppModule.database（preResolve）——
    // 懒单例在首次取用时才解析，此处次序只需在 ml 之后（EmbedIndexService 注入嵌入引擎）。
    ExternalModule(MoodiaryDataPackageModule),
    ExternalModule(MoodiaryAssistantPackageModule),
    ExternalModule(MoodiarySyncPackageModule),
    ExternalModule(MoodiaryEditorPackageModule),
  ],
  preferRelativeImports: false,
)
Future<void> configureDependencies() async {
  await getIt.init();
  _assertRequiredBindings();
}

/// 一个组合根必须提供的绑定清单——这就是 desktop 建自己的 di.dart 时要照着填的表。
/// 端口在包里、实现由 app 注册的跨包组合没有编译期约束，漏一条要等用户触发功能时
/// 才炸（如漏 IFilePicker = 点「插入图片」当场抛）；这里把失败提前到启动第一秒。
void _assertRequiredBindings() {
  final missing = <String>[
    if (!getIt.isRegistered<IKVStorage>()) 'IKVStorage',
    if (!getIt.isRegistered<MoodiaryDatabase>()) 'MoodiaryDatabase',
    if (!getIt.isRegistered<ISecureKVStorage>()) 'ISecureKVStorage',
    if (!getIt.isRegistered<IHttpClient>()) 'IHttpClient',
    if (!getIt.isRegistered<IHttpServer>()) 'IHttpServer',
    if (!getIt.isRegistered<IFilePicker>()) 'IFilePicker',
    if (!getIt.isRegistered<IHeifDecoder>()) 'IHeifDecoder',
    if (!getIt.isRegistered<IBackupArchive>()) 'IBackupArchive',
    if (!getIt.isRegistered<AssistantService>()) 'AssistantService',
    if (!getIt.isRegistered<SyncLogger>()) 'SyncLogger',
    if (!getIt.isRegistered<AutoSyncWatcher>()) 'AutoSyncWatcher',
    // 后端按名注册，名字与枚举 value 是运行时契约：这里替 @Named 补一道编译期没有的检查。
    for (final t in SyncProviderType.values)
      if (!getIt.isRegistered<IRemoteSyncBackend>(instanceName: t.value))
        'IRemoteSyncBackend(${t.value})',
  ];
  if (missing.isEmpty) return;
  logger.e('DI missing required bindings', error: missing);
  assert(false, 'DI 缺少必需绑定: $missing');
}
