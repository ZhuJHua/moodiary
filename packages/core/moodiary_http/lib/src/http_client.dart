import 'dart:convert';
import 'dart:typed_data';

import 'package:moodiary_rust/http.dart' show CancelToken;

export 'package:moodiary_rust/http.dart' show CancelToken;

enum HttpMethod { get, post, put, delete, patch, head, options }

class HttpResponse<T> {
  final int? statusCode;
  final T? data;
  final Map<String, String> headers;

  const HttpResponse({this.statusCode, this.data, this.headers = const {}});
}

class HttpBody {
  final Uint8List bytes;
  final String? contentType;

  const HttpBody.raw(this.bytes, {this.contentType});

  factory HttpBody.text(String text) => HttpBody.raw(
    .fromList(utf8.encode(text)),
    contentType: 'text/plain; charset=utf-8',
  );

  factory HttpBody.json(Object? value) => HttpBody.raw(
    .fromList(utf8.encode(jsonEncode(value))),
    contentType: 'application/json; charset=utf-8',
  );

  factory HttpBody.bytes(List<int> bytes, {String? contentType}) =>
      HttpBody.raw(.fromList(bytes), contentType: contentType);

  factory HttpBody.form(Map<String, dynamic> fields) {
    final encoded = fields.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent('${e.value}')}',
        )
        .join('&');
    return HttpBody.raw(
      .fromList(utf8.encode(encoded)),
      contentType: 'application/x-www-form-urlencoded',
    );
  }
}

enum HttpErrorType {
  timeout,
  connection,
  request,
  redirect,
  decode,
  statusCode,
  unknown,
}

class HttpException implements Exception {
  final HttpErrorType type;
  final int? statusCode;
  final String message;

  const HttpException(this.type, this.message, {this.statusCode});

  @override
  String toString() =>
      'HttpException($type${statusCode != null ? ' $statusCode' : ''}: $message)';
}

abstract class IHttpClient {
  IHttpClient();

  Future<HttpResponse<T>> request<T>(
    HttpMethod method,
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    HttpBody? body,
    Duration? timeout,
    bool silent = false,
    bool plainText = false,
  });

  Future<HttpResponse<T>> get<T>(
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    Duration? timeout,
    bool silent = false,
    bool plainText = false,
  }) => request<T>(
    .get,
    url,
    query: query,
    headers: headers,
    timeout: timeout,
    silent: silent,
    plainText: plainText,
  );

  Future<HttpResponse<T>> post<T>(
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    HttpBody? body,
    Duration? timeout,
    bool silent = false,
    bool plainText = false,
  }) => request<T>(
    .post,
    url,
    query: query,
    headers: headers,
    body: body,
    timeout: timeout,
    silent: silent,
    plainText: plainText,
  );

  Future<HttpResponse<Uint8List>> requestBytes(
    HttpMethod method,
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    HttpBody? body,
    Duration? timeout,
    bool silent = false,
    bool? throwOnStatus,
  });

  Future<void> downloadFile(
    String url,
    String destPath, {
    Map<String, dynamic>? headers,
    void Function(int received, int total)? onProgress,
    Duration? timeout,
    bool silent = false,
    CancelToken? cancel,
  });

  Future<HttpResponse<Uint8List>> uploadFile(
    String url, {
    required String filePath,
    HttpMethod method = .post,
    Map<String, dynamic>? headers,
    void Function(int sent, int total)? onProgress,
    Duration? timeout,
    bool silent = false,
    bool? throwOnStatus,
    CancelToken? cancel,
  });
}
