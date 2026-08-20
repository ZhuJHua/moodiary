import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_rust/foundation.dart' as rust;

/// [IHttpClient] 的 Rust(reqwest) 实现。opaque `HttpClient` 内含 reqwest 连接池，
/// 作为全局单例常驻、跨请求复用连接。
class RustHttpClient extends IHttpClient {
  RustHttpClient({this.onError})
    : _client = rust.HttpClient.newInstance(
        settings: const rust.ClientSettings(
          connectTimeoutMs: 5000,
          throwOnStatus: true,
        ),
      );

  /// 非 silent 请求失败时的回调（用于弹 toast）。
  final void Function(String message)? onError;

  /// 建 client 是异步的（frb 未标 sync）；只建一次，后续请求 await 已完成的 future。
  final Future<rust.HttpClient> _client;

  static const bool _enableLogging = kDebugMode;

  @override
  Future<HttpResponse<T>> request<T>(
    HttpMethod method,
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    HttpBody? body,
    Duration? timeout,
    bool silent = false,
    bool plainText = false,
  }) async {
    final raw = await _requestRaw(
      method,
      url,
      query: query,
      headers: headers,
      body: body,
      timeout: timeout,
      silent: silent,
    );
    final T? data;
    try {
      data = _decode<T>(raw.data!, plainText);
    } catch (error) {
      // 解码失败（非法 JSON / 类型不符）不是 rust.HttpError，需单独兜住，
      // 否则会绕过统一 catch、既不上报也不转成 HttpException。
      throw _report(
        HttpException(
          .decode,
          'decode failed: $error',
          statusCode: raw.statusCode,
        ),
        silent: silent,
      );
    }
    return HttpResponse<T>(
      statusCode: raw.statusCode,
      data: data,
      headers: raw.headers,
    );
  }

  @override
  Future<HttpResponse<Uint8List>> requestBytes(
    HttpMethod method,
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    HttpBody? body,
    Duration? timeout,
    bool silent = false,
    bool? throwOnStatus,
  }) => _requestRaw(
    method,
    url,
    query: query,
    headers: headers,
    body: body,
    timeout: timeout,
    silent: silent,
    throwOnStatus: throwOnStatus,
  );

  Future<HttpResponse<Uint8List>> _requestRaw(
    HttpMethod method,
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    HttpBody? body,
    Duration? timeout,
    bool silent = false,
    bool? throwOnStatus,
  }) async {
    if (_enableLogging) {
      logger.i('Request: ${method.name} $url');
    }
    try {
      // 建 client 也在 try 内：一旦（Android TLS 初始化等）建失败，rust.HttpError
      // 会被下面统一捕获并上报，而非以裸异常逃逸。
      final client = await _client;
      final response = await client.request(
        options: rust.RequestOptions(
          method: _method(method),
          url: url,
          query: _pairs(query),
          headers: _headers(headers, body),
          timeoutMs: timeout?.inMilliseconds,
          throwOnStatus: throwOnStatus,
        ),
        body: body?.bytes,
      );
      if (_enableLogging) {
        logger.i('Response ${response.status}');
      }
      return HttpResponse<Uint8List>(
        statusCode: response.status,
        data: response.body,
        headers: _headerMap(response.headers),
      );
    } on rust.HttpError catch (error) {
      throw _report(_exception(error), silent: silent);
    }
  }

  @override
  Future<HttpResponse<Uint8List>> uploadFile(
    String url, {
    required String filePath,
    HttpMethod method = .post,
    Map<String, dynamic>? headers,
    void Function(int sent, int total)? onProgress,
    Duration? timeout,
    bool silent = false,
    bool? throwOnStatus,
    rust.CancelToken? cancel,
  }) async {
    if (_enableLogging) {
      logger.i('Upload: ${method.name} $url ($filePath)');
    }
    try {
      final client = await _client;
      // 事件流：progress 事件 response 为 null，末条携带最终响应。
      await for (final event in client.uploadFile(
        options: rust.RequestOptions(
          method: _method(method),
          url: url,
          query: const [],
          headers: _pairs(headers),
          timeoutMs: timeout?.inMilliseconds,
          throwOnStatus: throwOnStatus,
        ),
        filePath: filePath,
        cancel: cancel ?? rust.CancelToken(),
      )) {
        final response = event.response;
        if (response == null) {
          onProgress?.call(event.sent, event.total);
          continue;
        }
        if (_enableLogging) {
          logger.i('Response ${response.status}');
        }
        return HttpResponse<Uint8List>(
          statusCode: response.status,
          data: response.body,
          headers: _headerMap(response.headers),
        );
      }
    } on rust.HttpError catch (error) {
      throw _report(_exception(error), silent: silent);
    } catch (error) {
      // 传输失败经 sink 下发，编解码固定为 AnyhowException，拿不到 kind 只有文本。
      throw _report(HttpException(.unknown, error.toString()), silent: silent);
    }
    throw const HttpException(.unknown, 'upload ended without response');
  }

  /// 非 silent 时上报错误（弹 toast），再返回原异常供调用方 `throw`。
  HttpException _report(HttpException exception, {required bool silent}) {
    if (!silent) {
      onError?.call(
        'Network Error ${exception.statusCode ?? ''} ${exception.message}'
            .trim(),
      );
    }
    return exception;
  }

  rust.HttpMethod _method(HttpMethod method) => switch (method) {
    .get => rust.HttpMethod.get_,
    .post => rust.HttpMethod.post,
    .put => rust.HttpMethod.put,
    .delete => rust.HttpMethod.delete,
    .patch => rust.HttpMethod.patch,
    .head => rust.HttpMethod.head,
    .options => rust.HttpMethod.options,
  };

  List<rust.KeyValue> _pairs(Map<String, dynamic>? map) {
    final pairs = <rust.KeyValue>[];
    map?.forEach((key, value) {
      if (value != null) {
        pairs.add(rust.KeyValue(key: key, value: '$value'));
      }
    });
    return pairs;
  }

  /// 合并调用方 headers 与请求体的 content-type（仅在调用方未显式给出时补上）。
  List<rust.KeyValue> _headers(Map<String, dynamic>? map, HttpBody? body) {
    final pairs = _pairs(map);
    final contentType = body?.contentType;
    if (contentType != null &&
        !pairs.any((kv) => kv.key.toLowerCase() == 'content-type')) {
      pairs.add(rust.KeyValue(key: 'content-type', value: contentType));
    }
    return pairs;
  }

  T? _decode<T>(Uint8List body, bool plainText) {
    if (body.isEmpty) return null;
    final text = utf8.decode(body, allowMalformed: true);
    if (plainText) return text as T;
    return jsonDecode(text) as T;
  }

  Map<String, String> _headerMap(List<rust.KeyValue> headers) {
    final map = <String, String>{};
    for (final kv in headers) {
      map[kv.key.toLowerCase()] = kv.value;
    }
    return map;
  }

  HttpException _exception(rust.HttpError error) {
    final type = switch (error.kind) {
      .timeout => HttpErrorType.timeout,
      .connect => HttpErrorType.connection,
      .request => HttpErrorType.request,
      .redirect => HttpErrorType.redirect,
      .decode => HttpErrorType.decode,
      .status => HttpErrorType.statusCode,
      .unknown => HttpErrorType.unknown,
    };
    return HttpException(type, error.message, statusCode: error.status);
  }
}
