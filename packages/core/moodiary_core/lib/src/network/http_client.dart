import 'dart:convert';
import 'dart:typed_data';

import 'package:moodiary_core/src/di.dart';

/// HTTP 方法。
enum HttpMethod { get, post, put, delete, patch, head, options }

/// 一次 HTTP 响应。[data] 由请求时的 `plainText` 决定：true 为原始字符串，
/// 否则为 `jsonDecode` 结果（空响应体为 null）。
class HttpResponse<T> {
  final int? statusCode;
  final T? data;
  final Map<String, String> headers;

  const HttpResponse({this.statusCode, this.data, this.headers = const {}});
}

/// 请求体。跨 FFI 前统一压平成「字节 + content-type」，json / form / text 的编码在此完成。
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

/// 网络异常分型，映射自 Rust 侧 `HttpErrorKind`。
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

/// 应用统一 HTTP 客户端接口。默认实现走 Rust(reqwest)，见 `RustHttpClient`。
abstract class IHttpClient {
  IHttpClient();

  factory IHttpClient.get() => getIt.get<IHttpClient>();

  /// 通用请求。[query] / [headers] 的值会被 `toString`，null 值跳过。[plainText] 为
  /// true 时 [HttpResponse.data] 为原始字符串，否则为 `jsonDecode` 结果。[silent]
  /// 抑制错误上报（仍会抛 [HttpException]）。
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

  /// 原始字节请求：响应体不做任何解码。[throwOnStatus] 为 false 时非 2xx 不抛
  /// [HttpException]，由调用方读 statusCode 自行分支；null 沿用实现默认（抛）。
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

  /// 流式上传本地文件（不整块进内存），[onProgress] 以 (已发送, 总字节) 回报。
  /// 响应体以原始字节返回。
  Future<HttpResponse<Uint8List>> uploadFile(
    String url, {
    required String filePath,
    HttpMethod method = .post,
    Map<String, dynamic>? headers,
    void Function(int sent, int total)? onProgress,
    Duration? timeout,
    bool silent = false,
    bool? throwOnStatus,
  });
}
