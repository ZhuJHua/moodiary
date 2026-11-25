import 'package:injectable/injectable.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:path/path.dart';

@module
abstract class AppModule {
  @lazySingleton
  StartupMigrationCoordinator startupMigrations() =>
      StartupMigrationCoordinator();

  @preResolve
  @singleton
  Future<IKVStorage> kvStorage(ISecureKVStorage secureKv) =>
      MmkvKVStorage.create(
        rootDir: join(PlatformService.get().applicationSupportPath, 'mmkv'),
        secureKv: secureKv,
      );

  @lazySingleton
  NotificationPermission notificationPermission() =>
      DeviceNotificationPermission();

  @lazySingleton
  IHttpClient httpClient() =>
      RustHttpClient(onError: (message) => toast.error(message: message));

  @preResolve
  @Singleton(dispose: closeDatabase)
  Future<MoodiaryDatabase> database(IKVStorage _) async {
    final db = await MoodiaryDatabase.open(
      path: AppFiles.getRealPath('database', 'moodiary.db'),
      jiebaDictDir: AppFiles.getRealPath('database', 'jieba'),
    );
    return db;
  }
}

Future<void> closeDatabase(MoodiaryDatabase db) => db.close();
