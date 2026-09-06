import 'package:injectable/injectable.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';

@module
abstract class AppModule {
  @lazySingleton
  IHttpClient httpClient() =>
      RustHttpClient(onError: (message) => toast.error(message: message));

  @preResolve
  @Singleton(dispose: closeDatabase)
  Future<MoodiaryDatabase> database() async {
    final db = await MoodiaryDatabase.open(
      path: AppFiles.getRealPath('database', 'moodiary.db'),
    );
    return db;
  }
}

Future<void> closeDatabase(MoodiaryDatabase db) => db.close();
