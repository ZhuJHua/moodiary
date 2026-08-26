import 'package:injectable/injectable.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_http/moodiary_http.dart';

/// 标准 injectable 用法里 @module 只装无法用类注解表达的构造：
/// RustHttpClient 的 onError 要接 app 的 toast，其余绑定都在实现类上自注解。
@module
abstract class AppModule {
  @lazySingleton
  IHttpClient httpClient() =>
      RustHttpClient(onError: (message) => toast.error(message: message));
}
