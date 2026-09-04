import 'package:injectable/injectable.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_mobile/app/di/bootstrap.dart' show bootMark;

/// 标准 injectable 用法里 @module 只装无法用类注解表达的构造：
/// RustHttpClient 的 onError 要接 app 的 toast；SQLite 的路径来自组合根
/// （moodiary_data 不认识文件布局），其余绑定都在实现类上自注解。
@module
abstract class AppModule {
  @lazySingleton
  IHttpClient httpClient() =>
      RustHttpClient(onError: (message) => toast.error(message: message));

  /// preResolve：容器装配完成即已打开并跑完建表 / 迁移，仓储（懒单例）取到的
  /// 一定是就绪的库。dispose 接 [closeDatabase]：`getIt.reset()` 时关连接池。
  @preResolve
  @Singleton(dispose: closeDatabase)
  Future<MoodiaryDatabase> database() async {
    bootMark('db.open start');
    final db = await MoodiaryDatabase.open(
      path: AppFiles.getRealPath('database', 'moodiary.db'),
    );
    bootMark('db.open end');
    return db;
  }
}

/// [AppModule.database] 的 dispose 回调（injectable 只收顶层函数，签名 `FutureOr Function(T)`）。
Future<void> closeDatabase(MoodiaryDatabase db) => db.close();
