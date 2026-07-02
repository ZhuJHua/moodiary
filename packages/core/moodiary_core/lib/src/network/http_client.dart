import 'package:moodiary_core/src/di.dart';

class HttpResponse<T> {
  final int? statusCode;
  final T? data;

  const HttpResponse({this.statusCode, this.data});
}

abstract interface class IHttpClient {
  factory IHttpClient.get() => getIt.get<IHttpClient>();

  Future<HttpResponse<T>> get<T>(
    String url, {
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? headers,
    Duration? timeout,
    bool silent = false,
    bool plainText = false,
  });
}
