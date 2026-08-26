import 'dart:convert';
import 'dart:io' show Directory;

import 'package:injectable/injectable.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_rust/foundation.dart' as rust;

/// [IHttpServer] 的 Rust(hyper) 实现。传输层全在 Rust：监听/端口回退、大请求体
/// 流式落盘、文件响应与 Range；本类只做类型转换，并保证跨 FFI 的 handler 回调
/// 绝不抛异常（Dart 侧任何错误统一折叠为 500）。
///
/// 注册是工厂而非单例：服务器是「按会话起停」的对象（编辑器 / 局域网接收各一），
/// 共享实例会让后启动的一方顶掉前一方的端口与 handler。
@Injectable(as: IHttpServer)
class RustHttpServer extends IHttpServer {
  rust.HttpServer? _server;

  @override
  Future<void> start({
    required HttpServerHandler handler,
    int preferredPort = 0,
    bool loopbackOnly = false,
    String? spoolDir,
    void Function(int received, int? total)? onBodyProgress,
  }) async {
    _server = await rust.HttpServer.start(
      preferredPort: preferredPort,
      loopbackOnly: loopbackOnly,
      spoolDir: spoolDir ?? Directory.systemTemp.path,
      onRequest: (request) async {
        try {
          final response = await handler(_request(request));
          return rust.HttpServerResponse(
            status: response.statusCode,
            headers: _pairs(response.headers),
            body: response.body,
            bodyFilePath: response.bodyFilePath,
          );
        } catch (e) {
          return rust.HttpServerResponse(
            status: 500,
            headers: _pairs(const {
              'content-type': 'text/plain; charset=utf-8',
            }),
            body: utf8.encode(e.toString()),
          );
        }
      },
      // 抛出不会击穿 FFI：Rust 侧把这个回调声明为可失败，异常会被解成 Err 后丢弃。
      onBodyProgress: (received, total) {
        onBodyProgress?.call(received, total < 0 ? null : total);
      },
    );
  }

  static HttpServerRequest _request(rust.HttpServerRequest request) =>
      HttpServerRequest(
        method: request.method,
        path: request.path,
        query: _map(request.query),
        headers: _map(request.headers),
        body: request.body,
        bodyFilePath: request.bodyFilePath,
      );

  /// 重复键保留首个。
  static Map<String, String> _map(List<rust.KeyValue> pairs) => {
    for (final kv in pairs.reversed) kv.key: kv.value,
  };

  static List<rust.KeyValue> _pairs(Map<String, String> map) => [
    for (final e in map.entries) rust.KeyValue(key: e.key, value: e.value),
  ];

  @override
  int get port => _server!.port();

  @override
  bool get isRunning => _server != null;

  @override
  Future<void> stop() async {
    final server = _server;
    _server = null;
    server?.stop();
  }
}
