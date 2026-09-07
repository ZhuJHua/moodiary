import 'dart:convert';
import 'dart:io' show Directory;

import 'package:injectable/injectable.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_rust/http.dart' as rust;

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
    await rust.MoodiaryRust.ensureInitialized();
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
