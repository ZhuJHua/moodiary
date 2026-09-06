import 'dart:convert';
import 'dart:typed_data';

class HttpServerRequest {
  final String method;

  final String path;

  final Map<String, String> query;

  final Map<String, String> headers;

  final Uint8List body;

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

abstract class IHttpServer {
  IHttpServer();

  Future<void> start({
    required HttpServerHandler handler,
    int preferredPort = 0,
    bool loopbackOnly = false,
    String? spoolDir,
    void Function(int received, int? total)? onBodyProgress,
  });

  int get port;

  bool get isRunning;

  Future<void> stop();
}
