import 'package:injectable/injectable.dart';
import 'package:moodiary_sync/src/data/model/sync_provider.dart';
import 'package:moodiary_sync/src/data/secure_options.dart';

/// 各后端的连接配置缓存，按 provider id 具名注册；后端构造器以同名 `@Named` 注入。
/// 进容器的意义：配置随后端一起归容器管，`getIt.reset()` 能清掉它（测试隔离），
/// 表单页不必再碰实现类的静态成员。
@module
abstract class SyncOptionsModule {
  @Named(SyncProviderIds.webdav)
  @lazySingleton
  SecureOptions webDavOptions() => SecureOptions(.webDavOption);

  @Named(SyncProviderIds.s3)
  @lazySingleton
  SecureOptions s3Options() => SecureOptions(.s3Option);
}
