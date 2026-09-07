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
import 'package:moodiary_theme/injectable.module.dart';

@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(MoodiaryStoragePackageModule),
    ExternalModule(MoodiaryHttpPackageModule),
    // AppModule 的 database / httpClient 在全部 micro-package 之后注册，包内 eager 单例不得依赖它们。
    ExternalModule(MoodiaryMlPackageModule),
    ExternalModule(MoodiaryDataPackageModule),
    ExternalModule(MoodiaryAssistantPackageModule),
    ExternalModule(MoodiarySyncPackageModule),
    ExternalModule(MoodiaryEditorPackageModule),
    ExternalModule(MoodiaryThemePackageModule),
  ],
  preferRelativeImports: false,
)
Future<void> configureDependencies() async {
  await getIt.init();
  _assertRequiredBindings();
}

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
    for (final t in SyncProviderType.values)
      if (!getIt.isRegistered<IRemoteSyncBackend>(instanceName: t.value))
        'IRemoteSyncBackend(${t.value})',
  ];
  if (missing.isEmpty) return;
  logger.e('DI missing required bindings', error: missing);
  assert(false, 'DI 缺少必需绑定: $missing');
}
