import 'package:moodiary_core/src/di.dart';

/// HTTP 响应的最小值类型，刻意不泄漏底层 Dio `Response`，便于 mock。
class HttpResponse<T> {
  final int? statusCode;
  final T? data;

  const HttpResponse({this.statusCode, this.data});
}

/// 可注入的 HTTP 客户端抽象，生产环境 get_it 注入 `DioHttpClient`，测试注入 fake。
abstract interface class IHttpClient {
  factory IHttpClient.get() => getIt.get<IHttpClient>();

  /// [timeout] 覆盖该次 connect / receive 超时。[silent]=true 时出错不弹 toast，
  /// 用于多源回退等「失败是预期、由调用方处理」的场景。
  Future<HttpResponse<T>> get<T>(
    String url, {
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? headers,
    Duration? timeout,
    bool silent = false,
  });
}
