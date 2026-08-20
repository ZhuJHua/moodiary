import 'dart:convert';
import 'dart:typed_data';

import 'package:moodiary_core/src/di.dart';

/// 收到的请求（body 已收集完毕才交给 handler）。
class HttpServerRequest {
  /// 大写方法名（GET / POST / ...）。
  final String method;

  /// 以 `/` 开头、不含 query。
  final String path;

  /// 已解码的 query 参数（重复键保留首个）。
  final Map<String, String> query;

  /// 头部键已小写。
  final Map<String, String> headers;

  /// 小请求体内联；已落盘时为空、见 [bodyFilePath]。
  final Uint8List body;

  /// 大请求体流式落盘的临时文件。仅在 handler 执行期间有效，返回后由服务器删除。
  final String? bodyFilePath;

  const HttpServerRequest({
    required this.method,
    required this.path,
    this.query = const {},
    this.headers = const {},
    required this.body,
    this.bodyFilePath,
  });
}

/// handler 返回的响应。[bodyFilePath] 非空时由服务器从磁盘流式发送，并自动支持
/// 单段 HTTP Range（webview `<video>` 依赖 206；此时 [body] 被忽略）。
class HttpServerResponse {
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List body;
  final String? bodyFilePath;

  HttpServerResponse(
    this.statusCode, {
    this.headers = const {},
    Uint8List? body,
    this.bodyFilePath,
  }) : body = body ?? Uint8List(0);

  factory HttpServerResponse.ok(List<int> body, {String? contentType}) =>
      HttpServerResponse(
        200,
        headers: {'content-type': ?contentType},
        body: .fromList(body),
      );

  factory HttpServerResponse.json(Object? value) => HttpServerResponse.ok(
    utf8.encode(jsonEncode(value)),
    contentType: 'application/json; charset=utf-8',
  );

  factory HttpServerResponse.text(int statusCode, String message) =>
      HttpServerResponse(
        statusCode,
        headers: const {'content-type': 'text/plain; charset=utf-8'},
        body: .fromList(utf8.encode(message)),
      );

  /// 从磁盘流式供给文件（自动支持 Range）。
  factory HttpServerResponse.file(
    String path, {
    required String contentType,
    Map<String, String> headers = const {},
  }) => HttpServerResponse(
    200,
    headers: {...headers, 'content-type': contentType},
    bodyFilePath: path,
  );

  factory HttpServerResponse.notFound() =>
      HttpServerResponse.text(404, 'not found');
}

typedef HttpServerHandler = Future<HttpServerResponse> Function(
  HttpServerRequest request,
);

/// 应用内 HTTP 服务的统一端口。默认实现走 Rust(hyper)，见 `RustHttpServer`。
/// 路由与业务在调用方的 [HttpServerHandler] 里；传输层（监听、请求体落盘、
/// 文件响应与 Range）由实现负责。
abstract class IHttpServer {
  IHttpServer();

  /// 每次调用返回一个新实例（get_it registerFactory）。
  factory IHttpServer.create() => getIt.get<IHttpServer>();

  /// 启动服务。[preferredPort] 被占自动回退随机端口（[port] 读实际值）；
  /// [loopbackOnly] 为 true 只监听 127.0.0.1，否则监听所有 IPv4 接口。
  /// 请求体超过阈值时流式落盘到 [spoolDir]（null → 系统临时目录），
  /// [onBodyProgress] 以 (received, total) 回报接收进度，total 为 null 表示长度未知。
  Future<void> start({
    required HttpServerHandler handler,
    int preferredPort = 0,
    bool loopbackOnly = false,
    String? spoolDir,
    void Function(int received, int? total)? onBodyProgress,
  });

  /// 实际监听端口，仅在 [start] 成功后可用。
  int get port;

  bool get isRunning;

  /// 停止监听并掐断在飞连接。幂等。
  Future<void> stop();
}
