import 'package:injectable/injectable.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

@module
abstract class AppModule {
  @lazySingleton
  IHttpClient httpClient() =>
      RustHttpClient(onError: (message) => toast.error(message: message));

  @preResolve
  @Singleton(dispose: closeDatabase)
  Future<MoodiaryDatabase> database() async {
    // 加密退避按版本计；appVersion 要到 VersionMigrator 才更新，所以在开库前比
    final info = await AppInfo.getPackageInfo();
    if (MoodiaryKVs.appVersion.get() != '${info.version}+${info.buildNumber}') {
      MoodiaryKVs.dbEncryptFailures.remove();
    }
    final db = await MoodiaryDatabase.open(
      path: AppFiles.getRealPath('database', 'moodiary.db'),
      jiebaDictDir: AppFiles.getRealPath('database', 'jieba'),
    );
    return db;
  }
}

Future<void> closeDatabase(MoodiaryDatabase db) => db.close();
