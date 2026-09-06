import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_rust/http.dart' as rust;

class RustHttpClient extends IHttpClient {
  RustHttpClient({this.onError});

  final void Function(String message)? onError;

  late final Future<rust.HttpClient> _client =
      rust.MoodiaryRust.ensureInitialized().then(
        (_) => rust.HttpClient.newInstance(
          settings: const rust.ClientSettings(
            connectTimeoutMs: 5000,
            throwOnStatus: true,
          ),
        ),
      );

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
  Future<void> downloadFile(
    String url,
    String destPath, {
    Map<String, dynamic>? headers,
    void Function(int received, int total)? onProgress,
    Duration? timeout,
    bool silent = false,
    rust.CancelToken? cancel,
  }) async {
    if (_enableLogging) {
      logger.i('Download: $url -> $destPath');
    }
    try {
      final client = await _client;
      await for (final event in client.downloadFile(
        options: rust.RequestOptions(
          method: _method(.get),
          url: url,
          query: const [],
          headers: _pairs(headers),
          timeoutMs: timeout?.inMilliseconds,
          throwOnStatus: true,
        ),
        destPath: destPath,
        cancel: cancel ?? rust.CancelToken(),
      )) {
        onProgress?.call(event.received, event.total);
      }
    } on rust.HttpError catch (error) {
      throw _report(_exception(error), silent: silent);
    } catch (error) {
      throw _report(HttpException(.unknown, error.toString()), silent: silent);
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
      throw _report(HttpException(.unknown, error.toString()), silent: silent);
    }
    throw const HttpException(.unknown, 'upload ended without response');
  }

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
