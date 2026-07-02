import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:moodiary_core/src/network/http_client.dart';
import 'package:moodiary_core/src/utils/log_util.dart';

class DioHttpClient implements IHttpClient {
  DioHttpClient({void Function(String message)? onError}) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          final silent = error.requestOptions.extra['silent'] == true;
          if (!silent && error.type != DioExceptionType.cancel) {
            onError?.call(
              'Network Error ${error.response?.statusCode} ${error.response?.statusMessage} ${error.message}',
            );
          }
          handler.next(error);
        },
        onRequest: (options, handler) {
          if (_enableLogging) {
            logger.i('Request: ${options.method} ${options.uri}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (_enableLogging) {
            logger.i('Response ${response.statusCode}');
          }
          handler.next(response);
        },
      ),
    );
  }

  static const bool _enableLogging = kDebugMode;

  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));

  @override
  Future<HttpResponse<T>> get<T>(
    String url, {
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? headers,
    Duration? timeout,
    bool silent = false,
    bool plainText = false,
  }) async {
    final response = await _dio.get<T>(
      url,
      queryParameters: parameters,
      options: Options(
        headers: headers,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        responseType: plainText ? ResponseType.plain : null,
        extra: {'silent': silent},
      ),
    );
    return HttpResponse<T>(
      statusCode: response.statusCode,
      data: response.data,
    );
  }
}
